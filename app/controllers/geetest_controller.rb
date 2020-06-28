require_relative 'geetest_config'
require_relative 'sdk/geetest_lib'

class GeetestController < ApplicationController

  protect_from_forgery except: ["second_validate"] # 跳过CSRF校验

  # 验证初始化接口，GET请求
  def first_register
    # 必传参数
    #     digestmod 此版本sdk可支持md5、sha256、hmac-sha256，md5之外的算法需特殊配置的账号，联系极验客服
    # 自定义参数,可选择添加
    #     user_id 客户端用户的唯一标识，确定用户的唯一性；作用于提供进阶数据分析服务，可在register和validate接口传入，不传入也不影响验证服务的使用；若担心用户信息风险，可作预处理(如哈希处理)再提供到极验
    #     client_type 客户端类型，web：电脑上的浏览器；h5：手机上的浏览器，包括移动应用内完全内置的web_view；native：通过原生sdk植入app应用的方式；unknown：未知
    #     ip_address 客户端请求sdk服务器的ip地址
    gt_lib = GeetestLib.new(GeetestConfig::GEETEST_ID, GeetestConfig::GEETEST_KEY)
    digestmod = "md5"
    user_id = "test"
    paramHash = {"digestmod" => digestmod, "user_id" => user_id, "client_type" => "web", "ip_address" => "127.0.0.1"}
    result = gt_lib.register(digestmod, paramHash)
    # 将结果状态写到session中，此处register接口存入session，后续validate接口会取出使用
    # 注意，此demo应用的session是单机模式，格外注意分布式环境下session的应用
    session[GeetestLib::GEETEST_SERVER_STATUS_SESSION_KEY] = result.getStatus
    session["user_id"] = user_id
    # 注意，不要更改返回的结构和值类型
    render :json => result.getData
  end

  # 二次验证接口，POST请求
  def second_validate
    gt_lib = GeetestLib.new(GeetestConfig::GEETEST_ID, GeetestConfig::GEETEST_KEY)
    challenge = params[GeetestLib::GEETEST_CHALLENGE]
    validate = params[GeetestLib::GEETEST_VALIDATE]
    seccode = params[GeetestLib::GEETEST_SECCODE]
    # session必须取出值，若取不出值，直接当做异常退出
    status = session[GeetestLib::GEETEST_SERVER_STATUS_SESSION_KEY]
    user_id = session["user_id"]
    if status.nil?
      render :json => {"result" => "fail", "version" => GeetestLib::VERSION, "msg" => "session取key发生异常"}
      return
    end
    if status == 1
      # 自定义参数,可选择添加
      #     user_id 客户端用户的唯一标识，确定用户的唯一性；作用于提供进阶数据分析服务，可在register和validate接口传入，不传入也不影响验证服务的使用；若担心用户信息风险，可作预处理(如哈希处理)再提供到极验
      #     client_type 客户端类型，web：电脑上的浏览器；h5：手机上的浏览器，包括移动应用内完全内置的web_view；native：通过原生sdk植入app应用的方式；unknown：未知
      #     ip_address 客户端请求sdk服务器的ip地址
      paramHash = {"user_id" => user_id, "client_type" => "web", "ip_address" => "127.0.0.1"}
      result = gt_lib.successValidate(challenge, validate, seccode, paramHash)
    else
      result = gt_lib.failValidate(challenge, validate, seccode)
    end
    # 注意，不要更改返回的结构和值类型
    if result.getStatus == 1
      response = {"result" => "success", "version" => GeetestLib::VERSION}
    else
      response = {"result" => "fail", "version" => GeetestLib::VERSION, "msg" => result.getMsg}
    end
    render :json => response
  end

end
