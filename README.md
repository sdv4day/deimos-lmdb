# deimos-lmdb

D 语言 LMDB (Lightning Memory-Mapped Database) 绑定库

## 简介

本库提供了 LMDB 的 D 语言接口绑定，基于 LMDB 0.9.70 版本。LMDB 是一个高性能的键值存储数据库，具有以下特点：

- 极快的读写性能
- ACID 事务支持
- 内存映射 I/O
- 无需缓存层
- 支持多线程/多进程并发访问

本库提供三种使用方式：
1. **底层 C 接口** (`deimos.lmdb`) - 直接映射 LMDB C API
2. **面向对象接口** (`deimos.lmdb_oop`) - 提供更友好的 D 语言 API  
3. **多进程共享客户端** (`deimos.shared_lmdb`) - 自动化多进程共享访问

## 安装

### 依赖

#### Windows
预编译的 LMDB 库已包含在 `libs/win64/lmdb.lib`

#### Linux
需要系统安装 LMDB 库：
```bash
# Ubuntu/Debian
sudo apt-get install liblmdb-dev

# CentOS/RHEL
sudo yum install lmdb-devel
```

### 使用 dub 添加依赖

在你的 `dub.json` 中添加：
```json
{
    "dependencies": {
        "deimos-lmdb": { "path": "path/to/deimos-lmdb" }
    }
}
```

或在 `dub.sdl` 中：
```sdl
dependency "deimos-lmdb" path="path/to/deimos-lmdb"
```

## 快速开始

### 使用面向对象接口（推荐）

```d
import deimos.lmdb_oop;
import std.stdio;

void main()
{
    // 创建环境
    auto env = new Environment()
        .setMapsize(1024 * 1024 * 10)
        .open("./testdb");
    
    // 写入数据
    {
        auto txn = new Transaction(env);
        auto db = new Database(txn, null, DatabaseFlags.MDB_CREATE);
        
        db.putString(txn, "key1", "value1");
        db.putString(txn, "key2", "value2");
        
        txn.commit();
    }
    
    // 读取数据
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        auto db = new Database(txn, null);
        writeln(db.getString(txn, "key1")); // 输出: value1
    }
    
    // 使用游标遍历
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        auto db = new Database(txn, null);
        auto cursor = new Cursor(txn, db);
        
        Val key, data;
        while (cursor.next(key, data))
        {
            writeln(key.asString, " = ", data.asString);
        }
    }
}
```

### 使用底层 C 接口

```d
import deimos.lmdb;
import std.stdio;
import std.string;

void main()
{
    MDB_env* env;
    MDB_txn* txn;
    MDB_dbi dbi;
    
    // 创建环境
    mdb_env_create(&env);
    mdb_env_set_mapsize(env, 1024 * 1024 * 10);
    mdb_env_open(env, "./testdb", 0, 0666);
    
    // 开始事务
    mdb_txn_begin(env, null, 0, &txn);
    mdb_dbi_open(txn, null, 0, &dbi);
    
    // 写入数据
    MDB_val key, data;
    key.mv_size = 3;
    key.mv_data = cast(void*)"key".ptr;
    data.mv_size = 5;
    data.mv_data = cast(void*)"value".ptr;
    
    mdb_put(txn, dbi, &key, &data, 0);
    
    // 读取数据
    MDB_val readData;
    mdb_get(txn, dbi, &key, &readData);
    
    // 提交事务
    mdb_txn_commit(txn);
    
    // 关闭环境
    mdb_dbi_close(env, dbi);
    mdb_env_close(env);
}
```

## API 概览

### 面向对象接口

#### 核心类
- `Environment` - 数据库环境管理
- `Transaction` - 事务管理
- `Database` - 数据库操作
- `Cursor` - 游标遍历
- `Val` - 值包装器

#### 辅助类型
- `LmdbException` - 异常类
- `CursorRange` - 游标范围遍历
- `KeyValueRange` - 键值对范围遍历

#### Environment 方法
- `setMapsize(size)` - 设置内存映射大小
- `setMaxReaders(count)` - 设置最大读取者数量
- `setMaxDbs(count)` - 设置最大数据库数量
- `open(path, flags, mode)` - 打开环境
- `sync(force)` - 同步到磁盘
- `close()` - 关闭环境

#### Database 方法
- `get(txn, key)` - 读取数据
- `put(txn, key, data, flags)` - 写入数据
- `del(txn, key)` - 删除数据
- `exists(txn, key)` - 检查键是否存在
- `getString(txn, key)` - 读取字符串
- `putString(txn, key, value)` - 写入字符串
- `getBinary(txn, key)` - 读取二进制数据
- `putBinary(txn, key, data)` - 写入二进制数据

#### Cursor 方法
- `first(key, data)` - 定位到第一条
- `last(key, data)` - 定位到最后一条
- `next(key, data)` - 移到下一条
- `prev(key, data)` - 移到上一条
- `set(key, data)` - 定位到指定键
- `setRange(key, data)` - 定位到大于等于指定键

### 底层 C 接口

#### 环境管理
- `mdb_env_create` - 创建环境句柄
- `mdb_env_open` - 打开环境
- `mdb_env_close` - 关闭环境
- `mdb_env_set_mapsize` - 设置内存映射大小
- `mdb_env_set_maxreaders` - 设置最大读取者数量
- `mdb_env_set_maxdbs` - 设置最大数据库数量

#### 事务管理
- `mdb_txn_begin` - 开始事务
- `mdb_txn_commit` - 提交事务
- `mdb_txn_abort` - 中止事务

#### 数据库操作
- `mdb_dbi_open` - 打开数据库
- `mdb_dbi_close` - 关闭数据库
- `mdb_get` - 读取数据
- `mdb_put` - 写入数据
- `mdb_del` - 删除数据

#### 游标操作
- `mdb_cursor_open` - 打开游标
- `mdb_cursor_close` - 关闭游标
- `mdb_cursor_get` - 游标读取
- `mdb_cursor_put` - 游标写入

## 枚举和常量

### 环境标志 (EnvironmentFlags)
- `MDB_RDONLY` - 只读模式
- `MDB_NOSYNC` - 不同步到磁盘
- `MDB_WRITEMAP` - 使用可写内存映射
- `MDB_NOTLS` - 不使用线程本地存储

### 数据库标志 (DatabaseFlags)
- `MDB_REVERSEKEY` - 反向键比较
- `MDB_DUPSORT` - 允许重复键
- `MDB_INTEGERKEY` - 整数键
- `MDB_CREATE` - 创建数据库

### 错误代码 (ErrorCodes)
- `MDB_SUCCESS` - 成功 (0)
- `MDB_KEYEXIST` - 键已存在
- `MDB_NOTFOUND` - 未找到
- `MDB_MAP_FULL` - 数据库已满

## 示例

- `examples/basic.d` - 底层 C 接口基础示例
- `examples/cursor.d` - 底层 C 接口游标示例
- `examples/oop.d` - 面向对象接口完整示例

## 构建和测试

```bash
# 构建库
dub build

# 运行底层接口示例
dub run --single examples/basic.d
dub run --single examples/cursor.d

# 运行面向对象示例
dub run --single examples/oop.d
```

## 特性

### 面向对象接口优势
- ✅ RAII 自动资源管理
- ✅ 异常安全
- ✅ 类型安全的 Val 包装器
- ✅ 流式 API 设计
- ✅ D 语言原生范围支持
- ✅ 中文注释和文档

### 性能特点
- 内存映射 I/O，零拷贝读取
- 极速的读写性能
- 小内存占用
- 支持大数据量（TB 级别）

## 许可证

本绑定库遵循与 LMDB 相同的 OpenLDAP Public License。

## 参考资料

- [LMDB 官方文档](http://www.lmdb.tech/doc/)
- [LMDB 源码](https://git.openldap.org/openldap/openldap/tree/mdb.master)
