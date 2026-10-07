package com.aiquant.mapper;

import com.aiquant.model.WalletTransaction;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface WalletTransactionMapper {

    @Insert("INSERT INTO t_wallet_transaction (user_id, currency, type, amount, channel, address, status, created_at) "
            + "VALUES (#{userId}, #{currency}, #{type}, #{amount}, #{channel}, #{address}, #{status}, #{createdAt})")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(WalletTransaction tx);

    @Select("SELECT * FROM t_wallet_transaction WHERE user_id = #{userId} AND currency = #{currency} "
            + "ORDER BY id DESC LIMIT #{limit} OFFSET #{offset}")
    List<WalletTransaction> selectByUser(@Param("userId") String userId,
                                         @Param("currency") String currency,
                                         @Param("limit") int limit,
                                         @Param("offset") int offset);
}
