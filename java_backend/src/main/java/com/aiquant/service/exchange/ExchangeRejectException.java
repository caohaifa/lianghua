package com.aiquant.service.exchange;

/**
 * 交易所明确拒单(响应可达但被拒绝,如余额不足/参数非法/风控拒绝)。
 * 与超时区分:拒单是终态,超时是结果未知。
 */
public class ExchangeRejectException extends RuntimeException {

    /** 交易所错误码(如币安 -2010),便于排障 */
    public final int exchangeCode;

    public ExchangeRejectException(int code, String message) {
        super(message);
        this.exchangeCode = code;
    }
}
