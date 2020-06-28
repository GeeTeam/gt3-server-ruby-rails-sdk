require "json"
require "net/http"

require_relative "geetest_lib_result"

# sdk lib包，核心逻辑。
class GeetestLib

  IS_DEBUG = true # 调试开关，是否输出调试日志
  API_URL = "http://api.geetest.com".freeze
  REGISTER_URL = "/register.php".freeze
  VALIDATE_URL = "/validate.php".freeze
  JSON_FORMAT = "1"
  NEW_CAPTCHA = true
  HTTP_TIMEOUT_DEFAULT = 5; # 单位：秒
  VERSION = "ruby-rails:3.1.0".freeze
  GEETEST_CHALLENGE = "geetest_challenge".freeze # 极验二次验证表单传参字段 chllenge
  GEETEST_VALIDATE = "geetest_validate".freeze # 极验二次验证表单传参字段 validate
  GEETEST_SECCODE = "geetest_seccode".freeze # 极验二次验证表单传参字段 seccode
  GEETEST_SERVER_STATUS_SESSION_KEY = "gt_server_status".freeze # 极验验证API服务状态Session Key


  def initialize(geetest_id, geetest_key)
    @geetest_id = geetest_id # 公钥
    @geetest_key = geetest_key # 私钥
    @libResult = GeetestLibResult.new()
  end

  def gtlog(msg)
    if IS_DEBUG
      puts "gtlog: #{msg}"
    end
  end

  # 验证初始化
  def register(digestmod, paramHash)
    gtlog("register(): 开始验证初始化, digestmod=#{digestmod}.");
    origin_challenge = requestRegister(paramHash)
    buildRegisterResult(origin_challenge, digestmod)
    gtlog("register(): 验证初始化, lib包返回信息=#{@libResult}.");
    @libResult
  end

  # 向极验发送验证初始化的请求，GET方式
  def requestRegister(paramHash)
    paramHash.merge!({"gt" => @geetest_id, "json_format" => JSON_FORMAT})
    register_url = API_URL + REGISTER_URL
    gtlog("requestRegister(): 验证初始化, 向极验发送请求, url=#{register_url}, params=#{paramHash}.")
    begin
      uri = URI(register_url)
      uri.query = URI.encode_www_form(paramHash)
      res = Net::HTTP.start(uri.host, uri.port, open_timeout: HTTP_TIMEOUT_DEFAULT, read_timeout: HTTP_TIMEOUT_DEFAULT) do |http|
        req = Net::HTTP::Get.new(uri)
        http.request(req)
      end
      res_body = res.is_a?(Net::HTTPSuccess) ? res.body : ""
      gtlog("requestRegister(): 验证初始化, 与极验网络交互正常, 返回码=#{res.code}, 返回body=#{res_body}.")
      res_hash = JSON.parse(res_body)
      origin_challenge = res_hash["challenge"]
    rescue => e
      gtlog("requestRegister(): 验证初始化, 请求异常，后续流程走宕机模式, " + e.message)
      origin_challenge = ""
    end
    origin_challenge
  end

  # 构建验证初始化返回数据
  def buildRegisterResult(origin_challenge, digestmod)
    # origin_challenge为空或者值为0代表失败
    if origin_challenge.nil? || origin_challenge.empty? || origin_challenge == "0"
      # 本地随机生成32位字符串
      challenge = (("a".."z").to_a + (0..9).to_a).shuffle[0, 32].join
      data = {:success => 0, :gt => @geetest_id, :challenge => challenge, :new_captcha => NEW_CAPTCHA}.to_json
      @libResult.setAll(0, data, "请求极验register接口失败，后续流程走宕机模式")
    else
      if digestmod == "md5"
        challenge = md5_encode(origin_challenge + @geetest_key)
      elsif digestmod == "sha256"
        challenge = sha256_endode(origin_challenge + @geetest_key)
      elsif digestmod == "hmac-sha256"
        challenge = hmac_sha256_endode(origin_challenge, @geetest_key)
      else
        challenge = md5_encode(origin_challenge + @geetest_key)
      end
      data = {:success => 1, :gt => @geetest_id, :challenge => challenge, :new_captcha => NEW_CAPTCHA}.to_json
      @libResult.setAll(1, data, "")
    end
  end

  # 正常流程下（即验证初始化成功），二次验证
  def successValidate(challenge, validate, seccode, paramHash)
    gtlog("successValidate(): 开始二次验证 正常模式, challenge=#{challenge}, validate=#{validate}, seccode=#{seccode}.")
    unless check_param(challenge, validate, seccode)
      @libResult.setAll(0, "", "正常模式，本地校验，参数challenge、validate、seccode不可为空")
    else
      response_seccode = requestValidate(challenge, validate, seccode, paramHash)
      if response_seccode.nil? || response_seccode.empty?
        @libResult.setAll(0, "", "请求极验validate接口失败")
      elsif response_seccode == "false"
        @libResult.setAll(0, "", "极验二次验证不通过")
      else
        @libResult.setAll(1, "", "")
      end
    end
    gtlog("successValidate(): 二次验证 正常模式, lib包返回信息=#{@libResult}.")
    @libResult
  end

  # 异常流程下（即验证初始化失败，宕机模式），二次验证
  # 注意：由于是宕机模式，初衷是保证验证业务不会中断正常业务，所以此处只作简单的参数校验，可自行设计逻辑。
  def failValidate(challenge, validate, seccode)
    gtlog("failValidate(): 开始二次验证 宕机模式, challenge=#{challenge}, validate=#{validate}, seccode=#{seccode}.")
    unless check_param(challenge, validate, seccode)
      @libResult.setAll(0, "", "宕机模式，本地校验，参数challenge、validate、seccode不可为空.")
    else
      @libResult.setAll(1, "", "")
    end
    gtlog("failValidate(): 二次验证 宕机模式, lib包返回信息=#{@libResult}.")
    @libResult
  end

  # 向极验发送二次验证的请求，POST方式
  def requestValidate(challenge, validate, seccode, paramHash)
    paramHash.merge!({"seccode" => seccode, "json_format" => JSON_FORMAT, "challenge" => challenge, "sdk" => VERSION, "captchaid" => @geetest_id})
    validate_url = API_URL + VALIDATE_URL
    gtlog("requestValidate(): 二次验证 正常模式, 向极验发送请求, url=#{validate_url}, params=#{paramHash}.")
    begin
      uri = URI(validate_url)
      res = Net::HTTP.start(uri.host, uri.port, open_timeout: HTTP_TIMEOUT_DEFAULT, read_timeout: HTTP_TIMEOUT_DEFAULT) do |http|
        req = Net::HTTP::Post.new(uri)
        req.set_form_data(paramHash)
        http.request(req)
      end
      res_body = res.is_a?(Net::HTTPSuccess) ? res.body : ""
      gtlog("requestValidate(): 二次验证 正常模式, 与极验网络交互正常, 返回码=#{res.code}, 返回body=#{res_body}.")
      res_hash = JSON.parse(res_body)
      seccode = res_hash["seccode"]
    rescue => e
      gtlog("requestValidate(): 二次验证 正常模式, 请求异常, " + e.message)
      seccode = ""
    end
    seccode
  end

  # 校验二次验证的三个参数，校验通过返回true，校验失败返回false
  def check_param(challenge, validate, seccode)
    return !(challenge.nil? || challenge.strip.empty? || validate.nil? || validate.strip.empty? || seccode.nil? || seccode.strip.empty?)
  end

  def md5_encode(msg)
    Digest::MD5.hexdigest(msg)
  end

  def sha256_endode(msg)
    Digest::SHA256.hexdigest(msg)
  end

  def hmac_sha256_endode(msg, private_key)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), private_key, msg)
  end

end
