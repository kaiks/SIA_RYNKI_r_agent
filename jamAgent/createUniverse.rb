require './Agent.rb'

def createAgents(agentClass, loginInfo, coef)
    created = 0
    agentIds = {}
    loginInfo.each {
            |id, password|
            begin
                agent = agentClass.createInstance(id, password, coef)
                created += 1
                agentIds.update({agent.id => agent})
            rescue Exception => e
				puts e
            end
            }
            # :-(
    return agentIds, {agentClass => created}
end


def createUniverse(agentDataDictionary)
    agents = {}
    createdAgents = {}
    agentDataDictionary.each do |agentClass, data|
                                    agentIds, created = createAgents(agentClass, data[:loginInfo], data[:coefficents])
                                    createdAgents.update(created) do 
                                                            |id, val1, val2| 
                                                             raise "duplicate in agentsCreatedupdate!"
															 end
                                    agents.update(agentIds) do
                                                            |id, val1, val2| 
                                                             raise "duplicate in agent.update!"
															 end
                                    
                             end
    return agents, createdAgents
end


def registerUser(password)
	sock = TCPSocket.new $host, $port
	sock.print RegisterUserReq.new(password).forge
	
	s, = IO.select [sock], [], [], 1
	raise "timeout while registering." if s[0] == nil
	
	registerAnswer = StockPacketIn.new sock.recv_nonblock(512)
	
	case registerAnswer.id
		when $packets[:REGISTER_USER_RESP_OK] then
			packet = RegisterUserRespOk.new(registerAnswer.get)
			puts "#{packet.user_id} registered succesfuly"
		when $packets[:REGISTER_USER_RESP_FAIL] then
			packet = RegisterUserRespFail.new(registerAnswer.get)
			raise "#{id} Register FAIL: #{packet.reason}"
		else
			raise "Either server send wrong message or protocol is flawed."
			return false
	end
	packet.user_id
end

def createUserAccounts(count)
	r = Random.new
	usersAccountsInfo = {}
	count.times { |value|
						password = r.rand(1000000..6000000).to_s
						begin
							usersAccountsInfo.merge! registerUser(password) => password
						rescue Exception => e
							puts e
						end
				}
	usersAccountsInfo
end


def startUniverse
	data = { :sleep_time => 0.3, 
			 :max_idle => 5}	
			 
	count = 1000
	
	agentsData = {SimpleAgent => {:coefficents => data, :loginInfo => createUserAccounts(count)}}
	
	
	agentIds, createdAgents = createUniverse(agentsData)
	
	puts "Created Agents: #{SimpleAgent}  =>  #{createdAgents[SimpleAgent]}"
	
	threads = {}
	
	agentIds.each do |id, obj|
						threads.merge! id => Thread.new {obj.start!}
					end
					
	threads.each do |id, th| 
							th.join()
					end
	
end

startUniverse

