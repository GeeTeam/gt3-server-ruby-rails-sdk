require_relative 'geetest_config'
require_relative 'sdk/geetest_lib'

class GeetestController < ApplicationController

  layout false # 不使用布局，直接返回纯html
  protect_from_forgery except: ["second_validate"] # 跳过CSRF校验

  def index
  end

  def first_register
    gt_lib = GeetestLib.new(GeetestConfig::GEETEST_ID, GeetestConfig::GEETEST_KEY)
    user_id = "test"
    digestmod = "md5"
    paramHash = Hash.new
    paramHash["digestmod"] = digestmod # 必传参数，此版本sdk可支持md5、sha256、hmac-sha256，md5之外的算法需特殊配置的账号，联系极验客服
    # 以下自定义参数,可选择添加
    paramHash["user_id"] = user_id # 网站用户id
    paramHash["client_type"] = "web" # web:电脑上的浏览器; h5:手机上的浏览器,包括移动应用内完全内置的web_view; native:通过原生SDK植入APP应用的方式
    paramHash["ip_address"] = "127.0.0.1" # 传输用户请求验证时所携带的IP
    result = gt_lib.register(digestmod, paramHash)
    # 将结果状态设置到session中
    # 注意，此处api1接口存入session，api2会取出使用，格外注意session的存取和分布式环境下的应用场景
    session[GeetestLib::GEETEST_SERVER_STATUS_SESSION_KEY] = result.getStatus
    session["user_id"] = user_id
    # 注意，不要更改返回的结构和值类型
    render :json => result.getData
  end

  def second_validate
    gt_lib = GeetestLib.new(GeetestConfig::GEETEST_ID, GeetestConfig::GEETEST_KEY)
    challenge = params[GeetestLib::GEETEST_CHALLENGE]
    validate = params[GeetestLib::GEETEST_VALIDATE]
    seccode = params[GeetestLib::GEETEST_SECCODE]
    # 从session中获取一次验证状态码和user_id
    status = session[GeetestLib::GEETEST_SERVER_STATUS_SESSION_KEY]
    user_id = session["user_id"]
    # session必须取出值，若取不出值，直接当做异常退出
    if status.nil?
      render :json => {"result" => "fail", "msg" => "session取key发生异常"}
      return
    end
    if status == 1
      paramHash = Hash.new
      # 自定义参数,可选择添加
      paramHash["user_id"] = user_id # 网站用户id
      paramHash["client_type"] = "web" # web:电脑上的浏览器; h5:手机上的浏览器,包括移动应用内完全内置的web_view; native:通过原生SDK植入APP应用的方式
      paramHash["ip_address"] = "127.0.0.1" # 传输用户请求验证时所携带的IP
      result = gt_lib.successValidate(challenge, validate, seccode, paramHash)
    else
      result = gt_lib.failValidate(challenge, validate, seccode)
    end
    if result.getStatus == 1
      response = {"result" => "success", "version" => GeetestLib::VERSION}
    else
      response = {"result" => "fail", "version" => GeetestLib::VERSION, "msg" => result.getMsg}
    end
    render :json => response
  end

end
