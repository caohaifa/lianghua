package com.aiquant.mapper;

import com.aiquant.model.RiskAssessment;
import org.apache.ibatis.annotations.*;

@Mapper
public interface RiskAssessmentMapper {

    @Insert("INSERT INTO t_risk_assessment (user_id, risk_level, score, answers_json, assessed_at) " +
            "VALUES (#{userId}, #{riskLevel}, #{score}, #{answersJson}, NOW())")
    int insert(RiskAssessment assessment);

    @Select("SELECT * FROM t_risk_assessment WHERE user_id = #{userId} ORDER BY assessed_at DESC LIMIT 1")
    RiskAssessment selectLatestByUserId(String userId);
}
