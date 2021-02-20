import ClashSupport

extension ClashConfig {
  public var quantumultXConfig: String {
    """
    [general]
    ;profile_img_url=http://www.example.com/example.png
    ;resource_parser_url=http://www.example.com/parser.js
    ;server_check_url=http://www.google.com/generate_204
    ;geo_location_checker=http://www.example.com/json/, https://www.example.com/script.js
    ;running_mode_trigger=filter, filter, LINK_22E171:all_proxy, LINK_22E172:all_direct
    dns_exclusion_list=*.cmpassport.com, *.jegotrip.com.cn, *.icitymobile.mobi, id6.me
    ;ssid_suspended_list=LINK_22E174, LINK_22E175
    ;udp_whitelist=53, 123, 1900, 80-443
    ;excluded_routes= 192.168.0.0/16, 172.16.0.0/12, 100.64.0.0/10, 10.0.0.0/8
    ;icmp_auto_reply=true

    [dns]
    \(dnsQXLines)

    [policy]
    \(policyQXLines)

    [server_remote]

    [filter_remote]

    [rewrite_remote]

    [server_local]
    \(serverLocalQXLines)

    [filter_local]
    \(filterLocalQXLines)

    [rewrite_local]

    [task_local]

    [mitm]

    """
  }
}
