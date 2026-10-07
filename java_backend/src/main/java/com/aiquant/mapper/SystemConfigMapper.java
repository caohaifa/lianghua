package com.aiquant.mapper;

import org.apache.ibatis.annotations.*;

@Mapper
public interface SystemConfigMapper {

    @Select("SELECT config_value FROM t_system_config WHERE config_key = #{key}")
    String get(String key);

    @Update("UPDATE t_system_config SET config_value = #{value}, updated_at = NOW() WHERE config_key = #{key}")
    int update(@Param("key") String key, @Param("value") String value);

    @Insert("INSERT INTO t_system_config (config_key, config_value, updated_at) VALUES (#{key}, #{value}, NOW())")
    int insert(@Param("key") String key, @Param("value") String value);

    @Select("SELECT config_key AS configkey, config_value AS configvalue, updated_at AS updatedat FROM t_system_config ORDER BY config_key")
    java.util.List<java.util.Map<String, Object>> selectAll();
}
