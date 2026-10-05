package com.aiquant.mapper;

import com.aiquant.model.AdminUser;
import org.apache.ibatis.annotations.*;

@Mapper
public interface AdminUserMapper {

    @Select("SELECT * FROM t_admin_user WHERE username = #{username}")
    AdminUser selectByUsername(String username);

    @Select("SELECT * FROM t_admin_user WHERE id = #{id}")
    AdminUser selectById(Long id);

    @Update("UPDATE t_admin_user SET password_hash = #{passwordHash} WHERE id = #{id}")
    int updatePasswordHash(@Param("id") Long id, @Param("passwordHash") String passwordHash);
}
