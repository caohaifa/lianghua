package com.aiquant.mapper;

import com.aiquant.model.Account;
import org.apache.ibatis.annotations.*;

@Mapper
public interface AccountMapper {

    @Insert("INSERT INTO t_account (user_id, currency, balance, created_at, updated_at) "
            +
            "VALUES (#{userId}, 'USDT', 100000, NOW(), NOW())")
    int initUsdt(String userId);

    @Insert("INSERT INTO t_account (user_id, currency, balance, created_at, updated_at) "
            +
            "VALUES (#{userId}, 'CNY', 1000000, NOW(), NOW())")
    int initCny(String userId);

    @Select("SELECT * FROM t_account WHERE user_id = #{userId} AND currency = #{currency}")
    Account selectByUserAndCurrency(@Param("userId") String userId,
                                    @Param("currency") String currency);

    @Update("UPDATE t_account SET balance = balance + #{delta}, updated_at = NOW() "
            +
            "WHERE user_id = #{userId} AND currency = #{currency}")
    int addBalance(@Param("userId") String userId,
                   @Param("currency") String currency,
                   @Param("delta") double delta);
}
