//
//  PYFMDB
//  pyFMDB 基于 FMDB的数据库封装操作处理类
//
//  Created by terry on 15/3/28.
//  Copyright (c) 2015年 Velda. All rights reserved.
//

#import "PYFMDB.h"
#import "FMDB.h"
@implementation PYFMDB
#pragma mark - set方法重写
/**
 *  重写tablename set方法
 *
 *  @param tablename 表名
 */
- (void)setCurrentTableName:(NSString *)currentTableName{
    _currentTableName = currentTableName;
    __block NSString *sql = [NSString stringWithFormat:@"PRAGMA table_info(%@%@)",self.prefix,_currentTableName];
    __block NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [_queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs= [db executeQuery:sql];
        while (rs.next) {
            [dict addEntriesFromDictionary: [NSDictionary dictionaryWithObject:[rs stringForColumn:@"type"] forKey:[rs stringForColumn:@"name"]]];
        }
    }];
    _currentTableFields = [NSDictionary dictionaryWithDictionary:dict];
    _lastSql = sql;
}

/**
 *  设置连接的数据库
 *
 *  @param database 数据库名称
 */
-(void)setDbName:(NSString *)dbName{
    _dbName = dbName;
    _dbPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:_dbName];
    _queue = [FMDatabaseQueue databaseQueueWithPath:_dbPath];
}

#pragma mark - get方法重写

/**
 *  重写fields get方法
 *
 *  @return 要查询的字段数组
 */
-(NSArray *)fields{
    if ([_fields count]==0) {
        _fields = [_currentTableFields allKeys];
    }
    return _fields;
}
/**
 *  重写prefix get方法
 *
 *  @return 数据库表前缀
 */
-(NSString *)prefix{
    if (_prefix) {
        return [NSString stringWithFormat:@"%@",_prefix];
    }
    return @"";
}
/**
 *  重写limit get方法
 *
 *  @return 返回limit 格式
 */
-(NSString *)limit{
    if (_limit.length==0) {
        return  [NSString stringWithFormat:@"LIMIT 0,10"];
    }
    return [NSString stringWithFormat:@"LIMIT %@",_limit];
}
/**
 *  重写where get 方法
 *
 *  @return 要查询的条件
 */

-(NSString *)where{
    if (_where.length>0) {
        return [NSString stringWithFormat:@" WHERE %@",_where];
    }
    return [NSString string];
}
/**
 *  重写order get方法
 *
 *  @return 要排序的条件
 */
- (NSString *)order{
    if(_order.length>0){
        return [NSString stringWithFormat:@" ORDER BY %@",_order];
    }
    return [NSString string];
}
/**
 *  重写group get方法
 *
 *  @return 要group的字段
 */
- (NSString *)group{
    if (_group.length >0) {
        return [NSString stringWithFormat:@" GROUP BY %@",_group];
    }
    return [NSString string];
}
/**
 *  重写 fieldsArray get方法
 *
 *  @return 数组版本fields
 */
-(NSArray *)fieldsArray{
    return _fields;
}
/**
 *  重写fieldsString get方法
 *
 *  @return 字符串版本fields
 */
-(NSString *)fieldsString{
   __block NSMutableString *str = [NSMutableString string];
    [self.fields enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        str = [NSMutableString stringWithFormat:@"%@,%@",str,obj];
    }];
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
}



#pragma mark - 创建数据库连接
/**
 *  静态方法创建数据库连接
 *
 *  @param dbName 数据库名
 *
 *  @return PYFMDB对象
 */
+(instancetype)dbWithDbName:(NSString *)dbName{
    return [[self alloc] initWithDbName:dbName];
}
/**
 *  动态方法创建数据库连接
 *
 *  @param dbName 数据库名
 *
 *  @return PYFMDB对象
 */
-(instancetype)initWithDbName:(NSString *)dbName{
    if(self =[super init]){
        [self setDbName:dbName];
    }
    return self;
}

#pragma mark -创建数据库表
/**
 *  根据字典创建数据库表
 *
 *  @param dict      字典 @{@"字段名称1":@"字段类型1",@"字段名称2":@"字段类型2"}
 *  @param tablename 表名
 *
 *  @return 返回bool类型 创建成功返回YES 失败返回NO
 */
- (bool)createTableWithDict:(NSDictionary *)dict :(NSString *)tableName{
    __block NSMutableString *sql = [NSMutableString stringWithFormat:@"CREATE TABLE IF NOT EXISTS `%@%@` (",_prefix,tableName];
    [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        sql = [NSMutableString stringWithFormat:@"%@ %@ %@,",sql,key,obj];
   }];
    //去除右侧多余 ','
    NSString *leftsql = [sql stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
    sql = [NSMutableString stringWithFormat:@"%@);",leftsql];
    _lastSql = sql;
    return [self excuteUpdateWithSql:sql];
}
/**
 *  为字段创建普通索引
 *
 *  @param field     字段名称
 *  @param tableName 表名
 *
 *  @return 执行是否成功
 */
-(bool)createIndexForField:(NSString *)field :(NSString *)tableName{
    __block NSMutableString *sql = [NSMutableString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@ ON %@%@(%@)",field,_prefix,tableName,field];
    _lastSql = sql;
    return [self excuteUpdateWithSql:sql];
}
#pragma mark - 执行数据库查询与更新
/**
 *  执行sql查询
 *
 *  @param sql sql语句
 *
 *  @return 查询结果集 数组NSArray
 */
- (NSArray *)excuteQueryWithSql:(NSString *)sql{
   __block NSArray *result = [NSArray array];
    [_queue inDatabase:^(FMDatabase *db) {
     NSMutableArray *arr = [NSMutableArray array];
     FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            for (int i=0; i<_fields.count; i++) {
               NSMutableString *key  = [NSMutableString stringWithString:[_fields objectAtIndex:i]];
                //过滤"xxx as yyy" 情况
                NSArray *keyarr =[key componentsSeparatedByString:@" as "];
                if ([keyarr count]>0) {
                   key =[NSMutableString stringWithString: [[keyarr lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                }
                //找到对应的currentTableField的type;keytype 只区分bloc和非bloc,非bloc一律转成nsstring
                NSMutableString *keytype = nil;
                //当key=*时则遍历_fields
                if ([key isEqualToString:@"*"]) {
                    for (int j=0; j<_currentTableFields.count; j++) {
                        key = [NSMutableString stringWithString:[_currentTableFields.allKeys objectAtIndex:j]];
                        keytype = [NSMutableString stringWithString:[_currentTableFields.allValues objectAtIndex:j]];
                        [keytype isEqualToString:@"bloc"] ? [dict setObject:[rs dataForColumn:key] forKey:key]:[dict setObject:[rs stringForColumn:key] forKey:key];
                    }
                }
                else{
                    //其他情况则分析key是否在currentTableFields.allKeys中是否存在
                    keytype = [_currentTableFields.allKeys containsObject:key] ?  _currentTableFields[key]:nil;
                    [keytype isEqualToString:@"bloc"] ? [dict setObject:[rs dataForColumn:key] forKey:key]:[dict setObject:[rs stringForColumn:key] forKey:key];
                }
            }
            [arr addObject:dict];
        }
        result  = [NSArray arrayWithArray:arr];
    }];
    //记录到最后sql
    _lastSql = sql;
    if(!result){
        NSLog(@"PYFMDB QUERY Empty: %@",sql);
    }
    return result;
}

/**
 *  执行sql更新
 *
 *  @param sql sql语句
 *
 *  @return bool YES执行成功 NO执行失败
 */
-(bool)excuteUpdateWithSql:(NSString *)sql{
    __block bool result;
    [_queue inDatabase:^(FMDatabase *db) {
        result = [db executeUpdate:sql];
    }];
    //记录到最后sql
    _lastSql = sql;
    //如果执行失败打印到前台
    if(!result){
        NSLog(@"PYFMDB UPDATE Failed: %@",sql);
    }
    return result;
}

#pragma mark - field 字段设置

/**
 *  从数组中设置要查询的字段信息
 *
 *  @param arr 数组
 *
 *  @return 无返回值
 */
- (instancetype)fieldsWithArray:(NSArray *)arr{
    _fields = arr;
    return self;
}

/**
 *  从字符串中设置要查询的字段信息
 *
 *  @param str 字符串
 *
 *  @return 无返回值
 */
- (instancetype)fieldsWithString:(NSString *)str{
    //将字符串转为数组
   NSArray *fields = [str componentsSeparatedByString:@","];
    if ([fields count]==0) {
        _fields = [NSArray arrayWithObject:str];
        return self;
    }
    __block NSMutableArray *result=[NSMutableArray array];
    [fields enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *trimobj = [obj stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [result addObject:trimobj];
    }];
    _fields = [NSArray arrayWithArray:result];
    return self;
}
#pragma mark - where条件设置
/**
 *  从字符串中设置要查询的where条件
 *
 *  @param str 字符串
 *
 *  @return where条件
 */
- (instancetype)whereWithString:(NSString *)str{
    _where = str;
    return self;
}
/**
 *  从字典中设置要查询的where条件
 *
 *  @param dict 字典
 *
 *  @return where条件
 */
-(instancetype)whereWithDict:(NSDictionary *)dict{
    NSMutableString *mutablestr = [NSMutableString string];
    NSArray *allkeys = [dict allKeys];
    NSMutableString *tmp = [NSMutableString string];
    for (int i=0; i<allkeys.count; i++) {
        id key = [allkeys objectAtIndex:i];
        id obj = [dict objectForKey:key];
        //value=数字 则直接等号赋值，不带单引号
        if ([obj isKindOfClass:[NSNumber class]]) {
            tmp = [NSMutableString stringWithFormat:@" `%@` = %@ AND ",key,obj];
        }
        //value=字符串则直接等号赋值
        if ([obj isKindOfClass:[NSString class]]) {
            tmp = [NSMutableString stringWithFormat:@" `%@` = '%@' AND ",key,[obj stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
        }
        //value=数组则提取赋值符号
        if ([obj isKindOfClass:[NSArray class]] ) {
            tmp = [NSMutableString stringWithFormat:@" `%@` %@ '%@' AND ",key,[obj objectAtIndex:0],[[obj objectAtIndex:1] stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
        }
        mutablestr = [NSMutableString stringWithFormat:@"%@%@",mutablestr,tmp];
    }
    _where = [NSString stringWithFormat:@"%@ 1",mutablestr];
    return self;
}

#pragma mark - limit 条件设置
/**
 *  从字符串中设置limit条件
 *
 *  @param str 字符串
 *
 *  @return PYFMDB对象
 */
- (instancetype)limitWithString:(NSString *)str{
    if ([str containsString:@","]) {
        _limit = str;
    }
    else{
        _limit = [NSString stringWithFormat:@"0,%@",str];
    }
    return self;
}
/**
 *  从数组中设置limit条件
 *
 *  @param arr 数组
 *
 *  @return PYFMDB对象
 */
-(instancetype)limitWithArray:(NSArray *)arr{
    if ([arr count]>1) {
        _limit = [arr componentsJoinedByString:@","];
    } else {
        _limit = [arr lastObject];
    }
    return self;
}
/**
 *  从start 到 end 的limit设置
 *
 *  @param start 开始位置
 *  @param End   结束位置
 *
 *  @return PYFMDB对象本身
 */
- (instancetype)limitWithStart:(int)start End:(int)end{
    _limit = [NSString stringWithFormat:@"%d,%d",start,end];
    return self;
}

#pragma mark - data 设置数据方法
/**
 *  从字典添加更新的数据源
 *
 *  @param dict PYFMDB对象
 */
- (instancetype)dataWithDict:(NSDictionary *)dict{
    _data = [self filterWithDict:dict];
    return self;
}
/**
 *  从数组添加更新的数据源
 *
 *  @param arr 数组
 *
 *  @return PYFMDB对象
 */
- (instancetype)dataWithArray:(NSArray *)arr{
    __block NSMutableArray *dataArr = [NSMutableArray array];
    if ([arr count]>0) {
        [arr enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dict = [self filterWithDict:obj];
                if([dict count] > 0){
                    [dataArr addObject:dict];
                }
            }
        }];
    }
    _data = [NSArray arrayWithArray:dataArr];
    return self;
}
/**
 *  从JSON添加更新的数据源
 *
 *  @param json json数据
 *
 *  @return PYFMDB对象
 */
-(instancetype)datawithJson:(NSData *)json{
    id jsondata = [NSJSONSerialization JSONObjectWithData:json options:0 error:nil];
    if([jsondata isKindOfClass:[NSDictionary class]]){
        _data = [self dataWithDict:jsondata];
    }
    if ([jsondata isKindOfClass:[NSArray class]]) {
        _data = [self dataWithArray:jsondata];
    }
    return self;
}

#pragma mark - 数据过滤
/**
 *  过滤非数据库表字段数据
 *
 *  @param dict 字典数据
 *
 *  @return 过滤后的字典数据
 */
- (NSDictionary *)filterWithDict:(NSDictionary *)dict{
   __block NSMutableDictionary *filterDict = [NSMutableDictionary dictionary];
    [[self.currentTableFields allKeys] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([dict objectForKey:obj]) {
            [filterDict addEntriesFromDictionary:[NSDictionary dictionaryWithObject:[dict objectForKey:obj] forKey:obj]];
        }
    }];
    return filterDict;
}

#pragma mark - 新增数据操作
/**
 *  新增记录到数据库
 *
 *  @return 是否执行sql成功
 */
- (bool)add{
    //字典单条记录更新
    if ([_data isKindOfClass:[NSDictionary class]] && [_data count]>0) {
        NSString *keys = [NSString stringWithFormat:@"`%@`",[[_data allKeys] componentsJoinedByString:@"`,`"]];
        //判断数据类型，数据类型为nsnumber则不加引号
        NSMutableString *allValues = [NSMutableString string];
        for (id object in [_data allValues]) {
            if ([object isKindOfClass:[NSNumber class]]) {
                allValues = [NSMutableString stringWithFormat:@"%@,%@",allValues,object];
            }
            else{
                //转义单引号
                NSMutableString *trueobj = [NSMutableString stringWithString:[object stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
                allValues = [NSMutableString stringWithFormat:@"%@,'%@'",allValues,trueobj];
            }
        }
        //去除两端逗号
        NSString *values =[NSString stringWithString:[allValues stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]]];
        NSString *sql = [NSString stringWithFormat:@"INSERT INTO `%@%@` (%@) values(%@);",self.prefix,self.currentTableName,keys,values];
         return [self excuteUpdateWithSql:sql];
    }
    //数组批量递归更新
    if ([_data isKindOfClass:[NSArray class]] && [_data count]>0) {
        __block bool alltrue = YES;
        [_data enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[NSDictionary class]] && ![self add:obj]) {
                alltrue = NO;
                NSLog(@"PYFMDB UPDATE FAILED:%@",self.lastSql);
            }
        }];
        return alltrue;
    }
    //其他则为异常情况
    NSLog(@"PYFMDB ADD DATA ERROR,DATA:%@",_data);
    return false;
}

/**
 *  根据数据源执行新增数据操作
 *
 *  @param data 数据源
 *
 *  @return 是否成功执行sql
 */

-(bool)add:(id)data{
    if ([data isKindOfClass:[NSDictionary class]]) {
        return [[self dataWithDict:data] add];
    }
    if ([data isKindOfClass:[NSArray class]]) {
        return [[self dataWithArray:data] add];
    }
    if ([data isKindOfClass:[NSData class]]) {
        return [[self datawithJson:data] add];
    }
    NSLog(@"PYFMDB ADD DATA ERROR,DATA:%@",data);
    return NO;
}




#pragma mark - 更新数据操作
/**
 *  更新记录到数据库
 *
 *  @return 是否执行sql成功
 */
- (bool)save{
    __block NSMutableString *setstring = [NSMutableString string];
    [_data enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        //判断数据类型
        if ([obj isKindOfClass:[NSNumber class]]) {
            setstring = [NSMutableString stringWithFormat:@"%@%@",setstring,[NSString stringWithFormat:@"`%@`=%@ and ",key,obj]];
        }
        else{
            //转义带单引号的数据源
            NSMutableString *trueobj = [NSMutableString stringWithString:[obj stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
            setstring = [NSMutableString stringWithFormat:@"%@%@",setstring,[NSString stringWithFormat:@"`%@`='%@' and ",key,trueobj]];
        }
    }];
   NSString * tmp  = [setstring stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" and "]];
    NSString *sql = [NSString stringWithFormat:@"UPDATE `%@%@` set %@ %@",self.prefix,self.currentTableName,tmp,self.where];
    return [self excuteUpdateWithSql:sql];
}
/**
 *  从字典更新记录到数据库
 *
 *  @param dict 字典数据
 *
 *  @return 是否执行sql成功
 */
- (bool)save:(id)data{
    if ([data isKindOfClass:[NSData class]]) {
        //从json导入数据
        [self datawithJson:data];
    }
    if ([data isKindOfClass:[NSDictionary class]] || [data isKindOfClass:[NSMutableDictionary class]]) {
        //从字典导入数据
        [self dataWithDict:data];
    }
    if ([data isKindOfClass:[NSArray class]] || [data isKindOfClass:[NSMutableArray class]]) {
        //从数组导入数据则遍历批量更新
        __block BOOL allsave=YES;
        [data enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            if ([obj isKindOfClass:[NSDictionary class]]) {
                [self dataWithDict:obj];
                if (![self save]) {
                    allsave = NO;
                    //打印到控制台错误信息
                    NSLog(@"PYFMDB UPDATE FAILED:%@",self.lastSql);
                }
            }
        }];
        return allsave;
    }
    return [self save];
}
/**
 *  更新指定字段值
 *
 *  @param value 字段值
 *  @param field 字段名
 *
 *  @return 是否执行sql成功
 */
- (bool)setValue:(id)value forField:(NSString *)field{
    _data = [self filterWithDict:[NSDictionary dictionaryWithObject:value forKey:field]];
    return  [self save];
}

#pragma mark - 获取数据

/**
 *  传入字符串 获取指定字段名的值
 *
 *  @param field 字段名
 *
 *  @return 字段值
 */
-(id)getField:(NSString *)field{
    NSDictionary *dict = [[self fieldsWithString:field] find];
    return [[dict allValues] lastObject];
}


/**
 *  查询单条记录
 *
 *  @return 字典数据
 */
- (NSDictionary *)find{
    //判断fields字段条件
    _fields = self.fields.count ==0 ? @[@"*"]:_fields;
    _limit = @"1";
    NSArray *arr = [self select];
    NSDictionary *result = [NSDictionary dictionaryWithDictionary:[arr lastObject]];
    return result;
}
/**
 *  查询全部结果集合
 *
 *  @return 结果数组
 */
- (NSArray *)select{
    _fields = self.fields.count ==0 ? @[@"*"]:_fields;
    _limit = _limit ? _limit:@"0,10";
    NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM `%@%@` %@ %@ %@;",self.fieldsString,self.prefix,self.currentTableName,self.where,self.order,self.limit];
    return [self excuteQueryWithSql:sql];
}

#pragma mark - 删除数据
/**
 *  删除操作
 *
 *  @return 是否成功执行sql
 */
- (BOOL)delete{
    NSString *sql = [NSString stringWithFormat:@"DELETE FROM `%@%@` %@",self.prefix,self.currentTableName,self.where];
    return [self excuteUpdateWithSql:sql];
}
/**
 *  根据where条件删除操作
 *
 *  @param where where条件[支持类型:字符串或者字典]
 *
 *  @return 是否成功执行sql
 */
- (BOOL)delete:(id)where{
    if([where isKindOfClass:[NSString class]]){
        return [[self whereWithString:where] delete];
    }
    if ([where isKindOfClass:[NSDictionary class]]) {
        return [[self whereWithDict:where] delete];
    }
    NSLog(@"PYFMDB WHERE CONDITIONS IS EMPTY,WHERE DATA:%@",where);
    return false;
}

#pragma mark - count统计
/**
 *  统计查询结果集合数量
 *
 *  @return 查询结果数量
 */
-(NSNumber *)queryCount{
    [self fieldsWithString:@"COUNT(*) as tmp"];
    [self setLimit:@"1"];
    NSArray *result =  [self select];
    return [[[result lastObject] allValues] lastObject];
}

#pragma mark - 设置状态
/**
 *  清除设置的状态
 *
 *  @return PYFMDB对象
 */
- (instancetype)clean{
    _fields = nil;
    _where = nil;
    _limit = nil;
    _data = nil;
    //pengyong prefix默认不重置
    //_prefix = nil;
    _order = nil;
    _group = nil;
    _lastSql = nil;
    _currentTableName = nil;
    return self;
}
/**
 *  锁定上次设置的状态
 *
 *  @return PYFMDB对象
 */
-(instancetype)lock{
    _fields_lock = _fields;
    _where_lock = _where;
    _limit_lock = _limit;
    _data_lock = _data;
    _prefix_lock = _prefix;
    _order_lock = _order;
    _group_lock =_group;
    _currentTableFields_lock = _currentTableFields;
    _currentTableName_lock = _currentTableName;
    _lastSql_lock = _lastSql;
    return self;
}
/**
 *  重置到上一次的状态
 *
 *  @return PYFMDB对象
 */
- (instancetype)reset{
    _fields = _fields_lock;
    _where =  _where_lock;
    _limit= _limit_lock;
    _data=_data_lock;
    _prefix = _prefix_lock;
    _order =_order_lock;
    _group =_group_lock;
    _currentTableFields = _currentTableFields_lock;
    _currentTableName = _currentTableName_lock;
    _lastSql = _lastSql_lock;
    return self;
}


@end
