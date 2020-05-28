# sdk lib包的返回结果信息。
class GeetestLibResult

  def initialize
    @status = 0 # 成功失败的标识码，1表示成功，0表示失败
    @data = '' # 返回数据，json格式
    @msg = '' # 备注信息，如异常信息等
  end

  def setStatus(status)
    @status = status
  end

  def getStatus
    @status
  end

  def setData(data)
    @data = data
  end

  def getData
    @data
  end

  def setMsg(msg)
    unless msg.nil? || msg.empty?
      @msg = msg
    end
  end

  def getMsg
    @msg
  end

  def setAll(status, data, msg)
    setStatus(status)
    setData(data)
    setMsg(msg)
  end

  def to_s
    "GeetestLibResult{status=#{@status}, data=#{@data}, msg=#{@msg}}"
  end

end

