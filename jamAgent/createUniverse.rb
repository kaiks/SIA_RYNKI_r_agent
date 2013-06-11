require 'Agent.rb'
require 'IrrationalPanicAgent.rb'

#Thread.abort_on_exception=true



def createAgents(agentClass, data)
    created = 0
    agentIds = {}
    data.each {
            |id, password, coef|
            begin			
				agent = agentClass.createInstance(id, password, coef)
				created += 1
                agentIds.update(agent.id => agent)
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
                                    agentIds, created = createAgents(agentClass, data)
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
	raise "timeout while registering." if s == nil
	
	registerAnswer = StockPacketIn.new sock.recv_nonblock(512)
	sock.close()
	case registerAnswer.id
		when $packets[:REGISTER_USER_RESP_OK] then
			packet = RegisterUserRespOk.new(registerAnswer.get)
			#puts "#{packet.user_id} registered succesfuly"
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

def runAsThreads(agentIds)
	threads = {}
	agentIds.each { |id, obj|
							threads.merge! id => Thread.new {obj.start!}}
	threads
end


def generateDataForAgent(agent, count)
	r = Random.new
	data  = []
	createUserAccounts(count).each { |id, password|
					data << [id, password, agent.generateRandomCoef(r)]
	}
	data
end

require 'date'
def startUniverse
	puts "[#{DateTime.now}] Starting new agent universe with #{ARGV[0]} agents...\n"
	count = ARGV[0].to_i
	agentsData = {IrrationalPanicAgent => generateDataForAgent(IrrationalPanicAgent, count)}
	
	
	agentIds, createdAgents = createUniverse(agentsData)
	Thread
	createdAgents.each { |agent_name, amount| puts "Created Agents: #{agent_name}  =>  #{amount}"}
	
	threads = runAsThreads(agentIds)
	
	puts "threads created: #{agentIds.length}"
	
	threads.each {|id, th| th.join()}
end 

startUniverse

