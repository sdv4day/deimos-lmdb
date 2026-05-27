/+ dub.sdl:
    name "generic-example"
    dependency "deimos-lmdb" path="../"
    targetType "executable"
+/

import deimos.lmdb_oop;
import std.stdio;
import std.file;

struct Point
{
    int x;
    int y;
}

void main()
{
    writeln("LMDB 泛型接口示例");
    writeln("==================");
    
    auto env = new Environment()
        .setMapsize(1024 * 1024 * 10)
        .setMaxDbs(2);
    
    if (!exists("./generic_testdb"))
        mkdir("./generic_testdb");
    env.open("./generic_testdb");
    
    Database db;
    
    writeln("\n1. 字符串键值...");
    {
        auto txn = new Transaction(env);
        db = new Database(txn, null, DatabaseFlags.MDB_CREATE);
        
        db.put(txn, "name", "张三");
        db.put(txn, "city", "北京");
        db.put(txn, "job", "工程师");
        
        writeln("  写入 3 条字符串数据");
        txn.commit();
    }
    
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        string name, city, job;
        if (db.get(txn, "name", name))
            writeln("  name = ", name);
        if (db.get(txn, "city", city))
            writeln("  city = ", city);
        if (db.get(txn, "job", job))
            writeln("  job = ", job);
    }
    
    writeln("\n2. 整数值...");
    {
        auto txn = new Transaction(env);
        db.put(txn, "age", 25);
        db.put(txn, "salary", 10000);
        db.put(txn, "count", 100L);
        writeln("  写入 3 条整数数据");
        txn.commit();
    }
    
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        int age, salary;
        long countVal;
        
        if (db.get(txn, "age", age))
            writeln("  age = ", age);
        if (db.get(txn, "salary", salary))
            writeln("  salary = ", salary);
        if (db.get(txn, "count", countVal))
            writeln("  count = ", countVal);
    }
    
    writeln("\n3. 浮点值...");
    {
        auto txn = new Transaction(env);
        db.put(txn, "pi", 3.14159);
        db.put(txn, "e", 2.71828);
        writeln("  写入 2 条浮点数据");
        txn.commit();
    }
    
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        double pi, e;
        if (db.get(txn, "pi", pi))
            writeln("  pi = ", pi);
        if (db.get(txn, "e", e))
            writeln("  e = ", e);
    }
    
    writeln("\n4. 整数键...");
    {
        auto txn = new Transaction(env);
        db.put(txn, 1, "第一个");
        db.put(txn, 2, "第二个");
        db.put(txn, 100, "第一百个");
        writeln("  写入 3 条整数键数据");
        txn.commit();
    }
    
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        string val;
        if (db.get(txn, 1, val))
            writeln("  1 = ", val);
        if (db.get(txn, 2, val))
            writeln("  2 = ", val);
        if (db.get(txn, 100, val))
            writeln("  100 = ", val);
    }
    
    writeln("\n5. POD 结构体...");
    {
        auto txn = new Transaction(env);
        
        Point p1 = Point(10, 20);
        Point p2 = Point(30, 40);
        
        db.put(txn, "point1", p1);
        db.put(txn, "point2", p2);
        
        writeln("  写入 2 个 Point 结构体");
        txn.commit();
    }
    
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        Point p;
        if (db.get(txn, "point1", p))
            writeln("  point1 = (", p.x, ", ", p.y, ")");
        if (db.get(txn, "point2", p))
            writeln("  point2 = (", p.x, ", ", p.y, ")");
    }
    
    writeln("\n6. 数组...");
    {
        auto txn = new Transaction(env);
        int[] arr = [1, 2, 3, 4, 5];
        db.put(txn, "array", arr);
        writeln("  写入数组: ", arr);
        txn.commit();
    }
    
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        int[] arr;
        if (db.get(txn, "array", arr))
            writeln("  读取数组: ", arr);
    }
    
    writeln("\n7. find 方法...");
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        writeln("  age = ", db.find(txn, "age", 0));
        writeln("  height = ", db.find(txn, "height", 180));
        writeln("  name = ", db.find(txn, "name", "未知"));
    }
    
    writeln("\n8. exists 方法...");
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        writeln("  name 存在: ", db.exists(txn, "name"));
        writeln("  age 存在: ", db.exists(txn, "age"));
        writeln("  nonexistent 存在: ", db.exists(txn, "nonexistent"));
        writeln("  1 存在: ", db.exists(txn, 1));
        writeln("  999 存在: ", db.exists(txn, 999));
    }
    
    writeln("\n9. 泛型删除...");
    {
        auto txn = new Transaction(env);
        db.del(txn, "job");
        db.del(txn, 100);
        writeln("  删除了 job 和键 100");
        txn.commit();
    }
    
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        writeln("  job 存在: ", db.exists(txn, "job"));
        writeln("  100 存在: ", db.exists(txn, 100));
    }
    
    writeln("\n10. 泛型游标遍历...");
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        auto cursor = new Cursor(txn, db);
        
        Val k, v;
        int count = 0;
        writeln("  正向遍历:");
        if (cursor.first(k, v))
        {
            do
            {
                writefln("    [%d] size=%d => size=%d", ++count, k.size, v.size);
            } while (cursor.next(k, v));
        }
    }
    
    writeln("\n11. 混合配置...");
    {
        auto txn = new Transaction(env);
        db.put(txn, "config.timeout", 30);
        db.put(txn, "config.host", "localhost");
        db.put(txn, "config.port", 8080);
        db.put(txn, "config.enabled", true);
        writeln("  写入配置数据");
        txn.commit();
    }
    
    {
        auto txn = new Transaction(env, EnvironmentFlags.MDB_RDONLY);
        scope(exit) txn.abort();
        
        int timeout, port;
        string host;
        bool enabled;
        
        if (db.get(txn, "config.timeout", timeout))
            writeln("  timeout = ", timeout);
        if (db.get(txn, "config.host", host))
            writeln("  host = ", host);
        if (db.get(txn, "config.port", port))
            writeln("  port = ", port);
        if (db.get(txn, "config.enabled", enabled))
            writeln("  enabled = ", enabled);
    }
    
    writeln("\n示例运行完成!");
}
