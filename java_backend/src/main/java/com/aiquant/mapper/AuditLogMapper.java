package com.aiquant.mapper;

import com.aiquant.model.AuditLog;
import org.apache.ibatis.annotations.*;

import java.util.List;

@Mapper
public interface AuditLogMapper {

    @Insert("INSERT INTO t_audit_log (actor_id, actor_type, action, resource, detail_json, ip, create_time) " +
            "VALUES (#{actorId}, #{actorType}, #{action}, #{resource}, #{detailJson}, #{ip}, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(AuditLog log);

    @Select("""
            <script>
            SELECT * FROM t_audit_log
            <where>
                <if test="actorId != null and actorId != ''"> AND actor_id = #{actorId} </if>
                <if test="action != null and action != ''"> AND action LIKE CONCAT('%', #{action}, '%') </if>
            </where>
            ORDER BY id DESC
            LIMIT #{size} OFFSET #{offset}
            </script>
            """)
    List<AuditLog> list(@Param("actorId") String actorId,
                        @Param("action") String action,
                        @Param("offset") int offset,
                        @Param("size") int size);

    @Select("""
            <script>
            SELECT COUNT(*) FROM t_audit_log
            <where>
                <if test="actorId != null and actorId != ''"> AND actor_id = #{actorId} </if>
                <if test="action != null and action != ''"> AND action LIKE CONCAT('%', #{action}, '%') </if>
            </where>
            </script>
            """)
    long count(@Param("actorId") String actorId, @Param("action") String action);
}
