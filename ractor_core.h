#include "internal/gc.h"
#include "ruby/ruby.h"
#include "ruby/ractor.h"
#include "vm_core.h"
#include "id_table.h"
#include "vm_debug.h"

#ifndef RACTOR_CHECK_MODE
#define RACTOR_CHECK_MODE (VM_CHECK_MODE || RUBY_DEBUG) && (SIZEOF_UINT64_T == SIZEOF_VALUE)
#endif

struct rb_ractor_sync {
    // ractor lock
    rb_nativethread_lock_t lock;

#if RACTOR_CHECK_MODE > 0
    VALUE locked_by;
#endif

#ifndef RUBY_THREAD_PTHREAD_H
    rb_nativethread_cond_t wakeup_cond;
#endif

    // incoming messages
    struct ractor_queue *recv_queue;

    // waiting threads for receiving
    struct ccan_list_head waiters;

    // ports
    VALUE default_port_value;
    struct st_table *ports;
    size_t next_port_id;

    // monitors
    struct ccan_list_head monitors;

    // value
    rb_ractor_t *successor;
    VALUE legacy;
    bool legacy_exc;
};

// created
//   | ready to run
// ====================== inserted to vm->ractor
//   v
// blocking <---+ all threads are blocking
//   |          |
//   v          |
// running -----+
//   | all threads are terminated.
// ====================== removed from vm->ractor
//   v
// terminated
//
// status is protected by VM lock (global state)
enum ractor_status {
    ractor_created,
    ractor_running,
    ractor_blocking,
    ractor_terminated,
};

struct rb_ractor_struct {
    struct rb_ractor_pub pub;
    struct rb_ractor_sync sync;

    // thread management
    struct {
        struct ccan_list_head set;
        unsigned int cnt;
        unsigned int blocking_cnt;
        unsigned int sleeper;
        struct rb_thread_sched sched;
        rb_execution_context_t *running_ec;
        rb_thread_t *main;
    } threads;

    VALUE thgroup_default;

    VALUE name;
    VALUE loc;

    enum ractor_status status_;

    struct ccan_list_node vmlr_node;

    // ractor local data

    st_table *local_storage;
    struct rb_id_table *idkey_local_storage;
    VALUE local_storage_store_lock;

    VALUE r_stdin;
    VALUE r_stdout;
    VALUE r_stderr;
    VALUE verbose;
    VALUE debug;

    void *newobj_cache;
}; // rb_ractor_t is defined in vm_core.h


static inline VALUE
rb_ractor_self(const rb_ractor_t *r)
{
    return r->pub.self;
}

rb_ractor_t *rb_ractor_main_alloc(void);
void rb_ractor_main_setup(rb_vm_t *vm, rb_ractor_t *main_ractor, rb_thread_t *main_thread);
void rb_ractor_atexit(rb_execution_context_t *ec, VALUE result);
void rb_ractor_atexit_exception(rb_execution_context_t *ec);
void rb_ractor_teardown(rb_execution_context_t *ec);
void rb_ractor_receive_parameters(rb_execution_context_t *ec, rb_ractor_t *g, int len, VALUE *ptr);
void rb_ractor_send_parameters(rb_execution_context_t *ec, rb_ractor_t *g, VALUE args);

VALUE rb_thread_create_ractor(rb_ractor_t *g, VALUE args, VALUE proc); // defined in thread.c

int rb_ractor_living_thread_num(const rb_ractor_t *);
VALUE rb_ractor_thread_list(void);
bool rb_ractor_p(VALUE rv);

void rb_ractor_living_threads_init(rb_ractor_t *r);
void rb_ractor_living_threads_insert(rb_ractor_t *r, rb_thread_t *th);
void rb_ractor_living_threads_remove(rb_ractor_t *r, rb_thread_t *th);
void rb_ractor_blocking_threads_inc(rb_ractor_t *r, const char *file, int line); // TODO: file, line only for RUBY_DEBUG_LOG
void rb_ractor_blocking_threads_dec(rb_ractor_t *r, const char *file, int line); // TODO: file, line only for RUBY_DEBUG_LOG

void rb_ractor_vm_barrier_interrupt_running_thread(rb_ractor_t *r);
void rb_ractor_terminate_interrupt_main_thread(rb_ractor_t *r);
void rb_ractor_terminate_all(void);
bool rb_ractor_main_p_(void);
void rb_ractor_atfork(rb_vm_t *vm, rb_thread_t *th);
void rb_ractor_terminate_atfork(rb_vm_t *vm, rb_ractor_t *th);
VALUE rb_ractor_require(VALUE feature, bool silent);
VALUE rb_ractor_autoload_load(VALUE space, ID id);

VALUE rb_ractor_ensure_shareable(VALUE obj, VALUE name);

RUBY_SYMBOL_EXPORT_BEGIN
void rb_ractor_finish_marking(void);

bool rb_ractor_shareable_p_continue(VALUE obj);

// THIS FUNCTION SHOULD NOT CALL WHILE INCREMENTAL MARKING!!
// This function is for T_DATA::free_func
void rb_ractor_local_storage_delkey(rb_ractor_local_key_t key);

RUBY_SYMBOL_EXPORT_END

static inline bool
rb_ractor_main_p(void)
{
    if (ruby_single_main_ractor) {
        return true;
    }
    else {
        return rb_ractor_main_p_();
    }
}

static inline bool
rb_ractor_status_p(rb_ractor_t *r, enum ractor_status status)
{
    return r->status_ == status;
}

static inline void
rb_ractor_sleeper_threads_inc(rb_ractor_t *r)
{
    r->threads.sleeper++;
}

static inline void
rb_ractor_sleeper_threads_dec(rb_ractor_t *r)
{
    r->threads.sleeper--;
}

static inline void
rb_ractor_sleeper_threads_clear(rb_ractor_t *r)
{
    r->threads.sleeper = 0;
}

static inline int
rb_ractor_sleeper_thread_num(rb_ractor_t *r)
{
    return r->threads.sleeper;
}

static inline void
rb_ractor_thread_switch(rb_ractor_t *cr, rb_thread_t *th, bool always_reset)
{
    RUBY_DEBUG_LOG("th:%d->%u%s",
                   cr->threads.running_ec ? (int)rb_th_serial(cr->threads.running_ec->thread_ptr) : -1,
                   rb_th_serial(th), cr->threads.running_ec == th->ec ? " (same)" : "");

    if (cr->threads.running_ec != th->ec || always_reset) {
        th->running_time_us = 0;
    }

    if (cr->threads.running_ec != th->ec) {
        if (0) {
            ruby_debug_printf("rb_ractor_thread_switch ec:%p->%p\n",
                              (void *)cr->threads.running_ec, (void *)th->ec);
        }
    }
    else {
        return;
    }

    cr->threads.running_ec = th->ec;

    VM_ASSERT(cr == GET_RACTOR());
}

#define rb_ractor_set_current_ec(cr, ec) rb_ractor_set_current_ec_(cr, ec, __FILE__, __LINE__)
#ifdef RB_THREAD_LOCAL_SPECIFIER
void rb_current_ec_set(rb_execution_context_t *ec);
#endif

static inline void
rb_ractor_set_current_ec_(rb_ractor_t *cr, rb_execution_context_t *ec, const char *file, int line)
{
#ifdef RB_THREAD_LOCAL_SPECIFIER
    rb_current_ec_set(ec);
#else
    native_tls_set(ruby_current_ec_key, ec);
#endif
    RUBY_DEBUG_LOG2(file, line, "ec:%p->%p", (void *)cr->threads.running_ec, (void *)ec);
    VM_ASSERT(ec == NULL || cr->threads.running_ec != ec);
    cr->threads.running_ec = ec;
}

void rb_vm_ractor_blocking_cnt_inc(rb_vm_t *vm, rb_ractor_t *cr, const char *file, int line);
void rb_vm_ractor_blocking_cnt_dec(rb_vm_t *vm, rb_ractor_t *cr, const char *file, int line);

static inline uint32_t
rb_ractor_id(const rb_ractor_t *r)
{
    return r->pub.id;
}

#if RACTOR_CHECK_MODE > 0
# define RACTOR_BELONGING_ID(obj) (*(uint32_t *)(((uintptr_t)(obj)) + rb_gc_obj_slot_size(obj)))

uint32_t rb_ractor_current_id(void);

static inline void
rb_ractor_setup_belonging_to(VALUE obj, uint32_t rid)
{
    RACTOR_BELONGING_ID(obj) = rid;
}

static inline uint32_t
rb_ractor_belonging(VALUE obj)
{
    if (SPECIAL_CONST_P(obj) || RB_OBJ_SHAREABLE_P(obj)) {
        return 0;
    }
    else {
        return RACTOR_BELONGING_ID(obj);
    }
}

extern bool rb_ractor_ignore_belonging_flag;

static inline VALUE
rb_ractor_confirm_belonging(VALUE obj)
{
    if (rb_ractor_ignore_belonging_flag) return obj;

    uint32_t id = rb_ractor_belonging(obj);

    if (id == 0) {
        if (UNLIKELY(!rb_ractor_shareable_p(obj))) {
            rp(obj);
            rb_bug("id == 0 but not shareable");
        }
    }
    else if (UNLIKELY(id != rb_ractor_current_id())) {
        if (rb_ractor_shareable_p(obj)) {
            // ok
        }
        else {
            rp(obj);
            rb_bug("rb_ractor_confirm_belonging object-ractor id:%u, current-ractor id:%u", id, rb_ractor_current_id());
        }
    }
    return obj;
}

static inline void
rb_ractor_ignore_belonging(bool flag)
{
    rb_ractor_ignore_belonging_flag = flag;
}

#else
#define rb_ractor_confirm_belonging(obj) obj
#define rb_ractor_ignore_belonging(flag) (0)
#endif
