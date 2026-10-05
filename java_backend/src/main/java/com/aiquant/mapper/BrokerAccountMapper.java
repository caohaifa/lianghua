package com.aiquant.mapper;

import com.aiquant.model.BrokerAccount;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface BrokerAccountMapper {

    @Insert("INSERT INTO t_broker_account (user_id, exchange, api_key, secret_key, passphrase, permissions, status, created_at) "
            +
            "VALUES (#{userId}, #{exchange}, #{apiKey}, #{secretKey}, #{passphrase}, #{permissions}, 0, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(BrokerAccount account);

    @Select("SELECT * FROM t_broker_account WHERE user_id = #{userId} ORDER BY id DESC")
    List<BrokerAccount> selectByUser(String userId);

    @Select("SELECT * FROM t_broker_account WHERE id = #{id} AND user_id = #{userId}")
    BrokerAccount selectByIdAndUser(@Param("id") Long id, @Param("userId") String userId);

    /** 实盘通道路由:取用户启用中的交易所凭据(最新一条) */
    @Select("SELECT * FROM t_broker_account WHERE user_id = #{userId} AND status = 0 ORDER BY id DESC LIMIT 1")
    BrokerAccount selectActive(String userId);

    @Delete("DELETE FROM t_broker_account WHERE id = #{id} AND user_id = #{userId}")
    int deleteByIdAndUser(@Param("id") Long id, @Param("userId") String userId);
}
