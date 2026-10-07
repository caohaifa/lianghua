package com.aiquant.mapper;

import com.aiquant.model.AgreementSignature;
import org.apache.ibatis.annotations.*;

@Mapper
public interface AgreementSignatureMapper {

    @Insert("INSERT INTO t_agreement_signature (user_id, agreements, signature_img, seal_time, ip, user_agent, content_hash, signed_at) " +
            "VALUES (#{userId}, #{agreements}, #{signatureImg}, #{sealTime}, #{ip}, #{userAgent}, #{contentHash}, NOW())")
    @Options(useGeneratedKeys = true, keyProperty = "id")
    int insert(AgreementSignature signature);

    @Select("SELECT * FROM t_agreement_signature WHERE user_id = #{userId} ORDER BY id DESC LIMIT 1")
    AgreementSignature selectLatestByUser(String userId);
}
