package com.aiquant.service.exchange;

/**
 * 交易所请求超时/网络异常:订单实际状态未知。
 * 调用方必须置 unknown 并等待对账,禁止自动重试(防重复下单)。
 */
public class ExchangeTimeoutException extends RuntimeException {

    public ExchangeTimeoutException(String message) {
        super(message);
    }
}
