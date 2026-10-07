package com.aiquant.mapper;

import com.aiquant.model.FuturesAccount;
import org.apache.ibatis.annotations.*;

@Mapper
public interface FuturesAccountMapper {

    @Insert("INSERT INTO t_futures_account (user_id, wallet_balance, created_at, updated_at) "
            + "VALUES (#{userId}, 10000, NOW(), NOW())")
    int initAccount(String userId);

    @Select("SELECT * FROM t_futures_account WHERE user_id = #{userId}")
    FuturesAccount selectByUser(String userId);

    @Update("UPDATE t_futures_account SET wallet_balance = #{walletBalance}, updated_at = NOW() "
            + "WHERE user_id = #{userId}")
    int updateWallet(@Param("userId") String userId,
                     @Param("walletBalance") double walletBalance);

    /** 增量原子更新(与现货 addBalance 同规则),避免读-改-写在并发下丢失更新 */
    @Update("UPDATE t_futures_account SET wallet_balance = wallet_balance + #{delta}, updated_at = NOW() "
            + "WHERE user_id = #{userId}")
    int addWallet(@Param("userId") String userId,
                  @Param("delta") double delta);
}
