module deimos.lmdb;

extern(C):

version(Windows)
{
    import core.sys.windows.windows;
}
else
{
    import core.sys.posix.sys.types;
}

enum MDB_VERSION_MAJOR = 0;
enum MDB_VERSION_MINOR = 9;
enum MDB_VERSION_PATCH = 70;
enum MDB_VERSION_DATE = "December 19, 2015";
enum MDB_VERSION_STRING = "LMDB 0.9.70: (December 19, 2015)";

version(Windows)
{
    alias mdb_mode_t = int;
    alias mdb_filehandle_t = void*;
}
else
{
    alias mdb_mode_t = mode_t;
    alias mdb_filehandle_t = int;
}

version(MDB_VL32)
{
    alias mdb_size_t = ulong;
    enum MDB_SIZE_MAX = ulong.max;
}
else
{
    alias mdb_size_t = size_t;
    enum MDB_SIZE_MAX = size_t.max;
}

struct MDB_env;
struct MDB_txn;
alias MDB_dbi = uint;
struct MDB_cursor;

struct MDB_val
{
    size_t mv_size;
    void* mv_data;
}

extern(D) struct MDB_val_D
{
    size_t mv_size;
    void* mv_data;
    
    T* dataAs(T)() pure nothrow @nogc @property
    {
        return cast(T*)mv_data;
    }
    
    T[] arrayAs(T)() pure nothrow @nogc @property
    {
        return cast(T[])mv_data[0 .. mv_size / T.sizeof];
    }
}

alias MDB_cmp_func = extern(C) int function(const MDB_val* a, const MDB_val* b);
alias MDB_rel_func = extern(C) void function(MDB_val* item, void* oldptr, void* newptr, void* relctx);
alias MDB_assert_func = extern(C) void function(MDB_env* env, const char* msg);
alias MDB_msg_func = extern(C) int function(const char* msg, void* ctx);

enum EnvironmentFlags : uint
{
    MDB_FIXEDMAP      = 0x01,
    MDB_NOSUBDIR      = 0x4000,
    MDB_NOSYNC        = 0x10000,
    MDB_RDONLY        = 0x20000,
    MDB_NOMETASYNC    = 0x40000,
    MDB_WRITEMAP      = 0x80000,
    MDB_MAPASYNC      = 0x100000,
    MDB_NOTLS         = 0x200000,
    MDB_NOLOCK        = 0x400000,
    MDB_NORDAHEAD     = 0x800000,
    MDB_NOMEMINIT     = 0x1000000,
    MDB_PREVSNAPSHOT  = 0x2000000,
}

enum DatabaseFlags : uint
{
    MDB_REVERSEKEY  = 0x02,
    MDB_DUPSORT     = 0x04,
    MDB_INTEGERKEY  = 0x08,
    MDB_DUPFIXED    = 0x10,
    MDB_INTEGERDUP  = 0x20,
    MDB_REVERSEDUP  = 0x40,
    MDB_CREATE      = 0x40000,
}

enum WriteFlags : uint
{
    MDB_NOOVERWRITE = 0x10,
    MDB_NODUPDATA   = 0x20,
    MDB_CURRENT     = 0x40,
    MDB_RESERVE     = 0x10000,
    MDB_APPEND      = 0x20000,
    MDB_APPENDDUP   = 0x40000,
    MDB_MULTIPLE    = 0x80000,
}

enum CopyFlags : uint
{
    MDB_CP_COMPACT = 0x01,
}

enum MDB_cursor_op
{
    MDB_FIRST,
    MDB_FIRST_DUP,
    MDB_GET_BOTH,
    MDB_GET_BOTH_RANGE,
    MDB_GET_CURRENT,
    MDB_GET_MULTIPLE,
    MDB_LAST,
    MDB_LAST_DUP,
    MDB_NEXT,
    MDB_NEXT_DUP,
    MDB_NEXT_MULTIPLE,
    MDB_NEXT_NODUP,
    MDB_PREV,
    MDB_PREV_DUP,
    MDB_PREV_NODUP,
    MDB_SET,
    MDB_SET_KEY,
    MDB_SET_RANGE,
    MDB_PREV_MULTIPLE,
}

enum ErrorCodes : int
{
    MDB_SUCCESS            = 0,
    MDB_KEYEXIST           = -30799,
    MDB_NOTFOUND           = -30798,
    MDB_PAGE_NOTFOUND      = -30797,
    MDB_CORRUPTED          = -30796,
    MDB_PANIC              = -30795,
    MDB_VERSION_MISMATCH   = -30794,
    MDB_INVALID            = -30793,
    MDB_MAP_FULL           = -30792,
    MDB_DBS_FULL           = -30791,
    MDB_READERS_FULL       = -30790,
    MDB_TLS_FULL           = -30789,
    MDB_TXN_FULL           = -30788,
    MDB_CURSOR_FULL        = -30787,
    MDB_PAGE_FULL          = -30786,
    MDB_MAP_RESIZED        = -30785,
    MDB_INCOMPATIBLE       = -30784,
    MDB_BAD_RSLOT          = -30783,
    MDB_BAD_TXN            = -30782,
    MDB_BAD_VALSIZE        = -30781,
    MDB_BAD_DBI            = -30780,
    MDB_PROBLEM            = -30779,
    MDB_LAST_ERRCODE       = MDB_PROBLEM,
}

struct MDB_stat
{
    uint ms_psize;
    uint ms_depth;
    mdb_size_t ms_branch_pages;
    mdb_size_t ms_leaf_pages;
    mdb_size_t ms_overflow_pages;
    mdb_size_t ms_entries;
}

struct MDB_envinfo
{
    void* me_mapaddr;
    mdb_size_t me_mapsize;
    mdb_size_t me_last_pgno;
    mdb_size_t me_last_txnid;
    uint me_maxreaders;
    uint me_numreaders;
}

char* mdb_version(int* major, int* minor, int* patch);
char* mdb_strerror(int err);

int mdb_env_create(MDB_env** env);
int mdb_env_open(MDB_env* env, const char* path, uint flags, mdb_mode_t mode);
int mdb_env_copy(MDB_env* env, const char* path);
int mdb_env_copyfd(MDB_env* env, mdb_filehandle_t fd);
int mdb_env_copy2(MDB_env* env, const char* path, uint flags);
int mdb_env_copyfd2(MDB_env* env, mdb_filehandle_t fd, uint flags);
int mdb_env_stat(MDB_env* env, MDB_stat* stat);
int mdb_env_info(MDB_env* env, MDB_envinfo* stat);
int mdb_env_sync(MDB_env* env, int force);
void mdb_env_close(MDB_env* env);
int mdb_env_set_flags(MDB_env* env, uint flags, int onoff);
int mdb_env_get_flags(MDB_env* env, uint* flags);
int mdb_env_get_path(MDB_env* env, const char** path);
int mdb_env_get_fd(MDB_env* env, mdb_filehandle_t* fd);
int mdb_env_set_mapsize(MDB_env* env, mdb_size_t size);
int mdb_env_set_maxreaders(MDB_env* env, uint readers);
int mdb_env_get_maxreaders(MDB_env* env, uint* readers);
int mdb_env_set_maxdbs(MDB_env* env, MDB_dbi dbs);
int mdb_env_get_maxkeysize(MDB_env* env);
int mdb_env_set_userctx(MDB_env* env, void* ctx);
void* mdb_env_get_userctx(MDB_env* env);
int mdb_env_set_assert(MDB_env* env, MDB_assert_func* func);

int mdb_txn_begin(MDB_env* env, MDB_txn* parent, uint flags, MDB_txn** txn);
MDB_env* mdb_txn_env(MDB_txn* txn);
mdb_size_t mdb_txn_id(MDB_txn* txn);
int mdb_txn_commit(MDB_txn* txn);
void mdb_txn_abort(MDB_txn* txn);
void mdb_txn_reset(MDB_txn* txn);
int mdb_txn_renew(MDB_txn* txn);

int mdb_dbi_open(MDB_txn* txn, const char* name, uint flags, MDB_dbi* dbi);
int mdb_stat(MDB_txn* txn, MDB_dbi dbi, MDB_stat* stat);
int mdb_dbi_flags(MDB_txn* txn, MDB_dbi dbi, uint* flags);
void mdb_dbi_close(MDB_env* env, MDB_dbi dbi);
int mdb_drop(MDB_txn* txn, MDB_dbi dbi, int del);

int mdb_set_compare(MDB_txn* txn, MDB_dbi dbi, MDB_cmp_func* cmp);
int mdb_set_dupsort(MDB_txn* txn, MDB_dbi dbi, MDB_cmp_func* cmp);
int mdb_set_relfunc(MDB_txn* txn, MDB_dbi dbi, MDB_rel_func* rel);
int mdb_set_relctx(MDB_txn* txn, MDB_dbi dbi, void* ctx);

int mdb_get(MDB_txn* txn, MDB_dbi dbi, MDB_val* key, MDB_val* data);
int mdb_put(MDB_txn* txn, MDB_dbi dbi, MDB_val* key, MDB_val* data, uint flags);
int mdb_del(MDB_txn* txn, MDB_dbi dbi, MDB_val* key, MDB_val* data);

int mdb_cursor_open(MDB_txn* txn, MDB_dbi dbi, MDB_cursor** cursor);
void mdb_cursor_close(MDB_cursor* cursor);
int mdb_cursor_renew(MDB_txn* txn, MDB_cursor* cursor);
MDB_txn* mdb_cursor_txn(MDB_cursor* cursor);
MDB_dbi mdb_cursor_dbi(MDB_cursor* cursor);
int mdb_cursor_get(MDB_cursor* cursor, MDB_val* key, MDB_val* data, MDB_cursor_op op);
int mdb_cursor_put(MDB_cursor* cursor, MDB_val* key, MDB_val* data, uint flags);
int mdb_cursor_del(MDB_cursor* cursor, uint flags);
int mdb_cursor_count(MDB_cursor* cursor, mdb_size_t* countp);

int mdb_cmp(MDB_txn* txn, MDB_dbi dbi, const MDB_val* a, const MDB_val* b);
int mdb_dcmp(MDB_txn* txn, MDB_dbi dbi, const MDB_val* a, const MDB_val* b);

int mdb_reader_list(MDB_env* env, MDB_msg_func* func, void* ctx);
int mdb_reader_check(MDB_env* env, int* dead);

deprecated("使用 mdb_dbi_open 代替")
{
    alias mdb_open = mdb_dbi_open;
}

deprecated("使用 mdb_dbi_close 代替")
{
    alias mdb_close = mdb_dbi_close;
}
