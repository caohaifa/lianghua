package com.aiquant.mapper;

import com.aiquant.model.User;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface UserMapper {

    @Insert("INSERT INTO t_user (user_id, phone, password_hash, nickname, status, created_at, updated_at) " +
            "VALUES (#{userId}, #{phone}, #{passwordHash}, #{nickname}, 0, NOW(), NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(User user);

    @Select("SELECT * FROM t_user WHERE phone = #{phone}")
    User selectByPhone(String phone);

    @Select("SELECT * FROM t_user WHERE user_id = #{userId}")
    User selectByUserId(String userId);

    @Update("UPDATE t_user SET risk_level = #{riskLevel}, updated_at = NOW() WHERE user_id = #{userId}")
    int updateRiskLevel(@Param("userId") String userId, @Param("riskLevel") String riskLevel);

    @Update("UPDATE t_user SET agreement_signed = 1, updated_at = NOW() WHERE user_id = #{userId}")
    int markAgreementSigned(String userId);

    @Update("UPDATE t_user SET trading_mode = #{mode}, updated_at = NOW() WHERE user_id = #{userId}")
    int updateTradingMode(@Param("userId") String userId, @Param("mode") String mode);

    @Update("UPDATE t_user SET password_hash = #{passwordHash}, updated_at = NOW() WHERE user_id = #{userId}")
    int updatePasswordHash(@Param("userId") String userId, @Param("passwordHash") String passwordHash);

    // ══════════════ 运营后台:用户管理 ══════════════

    @Select("""
            <script>
            SELECT id, user_id, phone, nickname, avatar, risk_level, agreement_signed,
                   device_id, status, created_at, updated_at
            FROM t_user
            <where>
                <if test="keyword != null and keyword != ''">
                    AND (phone LIKE CONCAT('%', #{keyword}, '%')
                         OR nickname LIKE CONCAT('%', #{keyword}, '%')
                         OR user_id LIKE CONCAT('%', #{keyword}, '%'))
                </if>
                <if test="status != null"> AND status = #{status} </if>
                <if test="riskLevel != null and riskLevel != ''"> AND risk_level = #{riskLevel} </if>
            </where>
            ORDER BY id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<User> adminList(@Param("keyword") String keyword,
                         @Param("status") Integer status,
                         @Param("riskLevel") String riskLevel,
                         @Param("offset") int offset,
                         @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_user
            <where>
                <if test="keyword != null and keyword != ''">
                    AND (phone LIKE CONCAT('%', #{keyword}, '%')
                         OR nickname LIKE CONCAT('%', #{keyword}, '%')
                         OR user_id LIKE CONCAT('%', #{keyword}, '%'))
                </if>
                <if test="status != null"> AND status = #{status} </if>
                <if test="riskLevel != null and riskLevel != ''"> AND risk_level = #{riskLevel} </if>
            </where>
            </script>
            """)
    long adminCount(@Param("keyword") String keyword,
                    @Param("status") Integer status,
                    @Param("riskLevel") String riskLevel);

    @Update("UPDATE t_user SET status = #{status}, updated_at = NOW() WHERE user_id = #{userId}")
    int updateStatus(@Param("userId") String userId, @Param("status") int status);

    @Update("UPDATE t_user SET risk_level = #{riskLevel}, updated_at = NOW() WHERE user_id = #{userId}")
    int adminUpdateRiskLevel(@Param("userId") String userId, @Param("riskLevel") String riskLevel);
}
