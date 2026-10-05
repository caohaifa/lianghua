package com.aiquant;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@MapperScan("com.aiquant.mapper")
@EnableScheduling
public class AiQuantApplication {
    public static void main(String[] args) {
        SpringApplication.run(AiQuantApplication.class, args);
    }
}
