require "json"
require "net/http"

require_relative "geetest_lib_result"

# sdk lib包，核心逻辑。
class GeetestLib

  IS_DEBUG = true # 调试开关，是否输出调试日志
  VERSION = "ruby-rails:3.1.0".freeze
  API_URL = "http://api.geetest.com".freeze
  REGISTER_URL = "/register.php".freeze
  VALIDATE_URL = "/validate.php".freeze
  JSON_FORMAT = 1
  NEW_CAPTCHA = true
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

  # 一次验证
  def register(paramHash, digestmod)
    gtlog("register(): 开始一次验证, digestmod=#{digestmod}.");
    origin_challenge = requestRegister(paramHash)
    buildRegisterResult(origin_challenge, digestmod)
    gtlog("register(): 一次验证, lib包返回信息=#{@libResult}.");
    @libResult
  end

  # 向极验发送一次验证的请求，GET方式
  def requestRegister(paramHash)
    paramHash["gt"] = @geetest_id
    paramHash["json_format"] = JSON_FORMAT
    register_url = API_URL + REGISTER_URL
    uri = URI(register_url)
    uri.query = URI.encode_www_form(paramHash)
    gtlog("requestRegister(): 一次验证向极验发送请求, url=#{ API_URL}, paramHash=#{paramHash}.")
    begin
      res = Net::HTTP.get_response(uri)
      if res.is_a?(Net::HTTPSuccess)
        res_body = res.body
      else
        res_body = ""
      end
      gtlog("requestRegister(): 一次验证请求正常, 返回码=#{res.code}, 返回body=#{res_body}.")
      res_hash = JSON.parse(res_body)
      origin_challenge = res_hash["challenge"]
    rescue
      origin_challenge = ""
    end
    origin_challenge
  end

  # 构建一次验证返回数据
  def buildRegisterResult(origin_challenge, digestmod)
    # origin_challenge为空或者值为0代表失败
    if origin_challenge.nil? || origin_challenge.empty? || origin_challenge == "0"
      # 本地随机生成32位字符串
      challenge = (("a".."z").to_a + (0..9).to_a + ("A".."Z").to_a).shuffle[0, 32].join
      data = {:success => 0, :gt => @geetest_id, :challenge => challenge, :new_captcha => NEW_CAPTCHA}.to_json
      @libResult.setAll(0, data, "请求极验register接口失败，后续流程走failback模式")
    else
      if digestmod == "md5"
        challenge = md5_encode(origin_challenge + @geetest_key)
      elsif digestmod == "sha256"
        challenge = sha256_endode(origin_challenge + @geetest_key)
      elsif digestmod == "hmac-sha256"
        challenge = hmacsha256_endode(origin_challenge, @geetest_key)
      else
        challenge = md5_encode(origin_challenge + @geetest_key)
      end
      data = {:success => 1, :gt => @geetest_id, :challenge => challenge, :new_captcha => NEW_CAPTCHA}.to_json
      @libResult.setAll(1, data, "")
    end
  end

  # 正常流程下（即一次验证请求成功），二次验证
  def successValidate(challenge, validate, seccode, paramHash)
    gtlog("successValidate(): 开始二次验证 正常模式, challenge=#{challenge}, validate=#{validate}, seccode=#{seccode}.")
    unless check_param(challenge, validate, seccode)
      @libResult.setAll(0, "", "正常模式，本地校验，参数challenge、validate、seccode不可为空")
    else
      seccode = requestValidate(challenge, validate, seccode, paramHash)
      if seccode.nil? || seccode.empty?
        @libResult.setAll(0, "", "请求极验validate接口失败")
      elsif seccode == "false"
        @libResult.setAll(0, "", "极验二次验证不通过")
      else
        @libResult.setAll(1, "", "")
      end
    end
    gtlog("successValidate(): 二次验证 正常模式, lib包返回信息=#{@libResult}.")
    @libResult
  end

  # 异常流程下（即failback模式），二次验证
  # 注意：由于是failback模式，初衷是保证验证业务不会中断正常业务，所以此处只作简单的参数校验，可自行设计逻辑。
  def failValidate(challenge, validate, seccode)
    gtlog("failValidate(): 开始二次验证 failback模式, challenge=#{challenge}, validate=#{validate}, seccode=#{seccode}.")
    unless check_param(challenge, validate, seccode)
      @libResult.setAll(0, "", "failback模式，本地校验，参数challenge、validate、seccode不可为空.")
    else
      @libResult.setAll(1, "", "")
    end
    gtlog("failValidate(): 二次验证 failback模式, lib包返回信息=#{@libResult}.")
    @libResult
  end

  # 向极验发送二次验证的请求，POST方式
  def requestValidate(challenge, validate, seccode, paramHash)
    paramHash["seccode"] = seccode
    paramHash["json_format"] = JSON_FORMAT
    paramHash["challenge"] = challenge
    paramHash["sdk"] = VERSION
    paramHash["captchaid"] = @geetest_id
    validate_url = API_URL + VALIDATE_URL
    uri = URI(validate_url)
    gtlog("requestRegister(): 二次验证 正常模式, 向极验发送请求, url=#{validate_url}, paramHash=#{paramHash}.")
    begin
      res = Net::HTTP.post_form(uri, paramHash)
      res_body = res.body
      gtlog("requestRegister(): 二次验证 正常模式, 请求正常, 返回码=#{res.code}, 返回body=#{res_body}.")
      res_hash = JSON.parse(res_body)
      seccode = res_hash["seccode"]
    rescue
      seccode = ""
    end
    seccode
  end

  # 校验二次验证的三个参数，校验通过返回true，校验失败返回false
  def check_param(challenge, validate, seccode)
    if challenge.nil? || challenge.strip.empty? || validate.nil? || validate.strip.empty? || seccode.nil? || seccode.strip.empty?
      return false
    end
    true
  end

  def md5_encode(msg)
    Digest::MD5.hexdigest(msg)
  end

  def sha256_endode(msg)
    Digest::SHA256.hexdigest(msg)
  end

  def hmacsha256_endode(msg, private_key)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), private_key, msg)
  end

end
