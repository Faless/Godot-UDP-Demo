extends Node

export var port = 4666
export var max_conns = 4

var server
var udpserver = null
var udpstream = null

var clients = []
var streams = []
var handler = null
var debug = null

class UDPServer:
	var handler = null
	
	const PAYLOAD_SIZE = 200
	const PENDING_TIMEOUT = 10
	var udpstream = PacketPeerUDP.new()
	var udpclients = []
	var pending = {}
	var port
	
	func _init(port):
		self.port = port
	
	func listen():
		return udpstream.listen( port )
	
	func close():
		udpstream.close()
	
	var queue = []
	func update():
		if queue.size() > 0:
			udpstream.set_send_address( queue[0].host, queue[0].port )
			udpstream.put_var(queue[0].msg)
			queue.remove(0)
		pass
	
	func send_data(message, host, port):
		var packet = {0:message}.to_json()
		var packets = []
		while packet.length() > PAYLOAD_SIZE:
			packets.append(packet.left(PAYLOAD_SIZE))
			packet = packet.right(PAYLOAD_SIZE)
		packets.append(packet)
		var id = randi()
		var l = packets.size()
		var i = 0
		for p in packets:
			queue.append({msg=[id, l, i, p],host=host,port=port})
			i += 1
	
	func process_packets():
		var obj
		update()
		while udpstream.get_available_packet_count() > 0:
			var data = udpstream.get_var()
			if typeof(data) == TYPE_INT:
				obj = auth(data)
				if obj != null:
					udpclients.append({client=obj, \
										address=udpstream.get_packet_ip(), \
										port=udpstream.get_packet_port() \
									})
					if handler != null and handler.has_method("on_auth"):
						handler.on_auth(data, obj, udpstream.get_packet_ip(), udpstream.get_packet_port())
					print("Added client: ", udpclients[udpclients.size()-1])
			else:
				print("Invalid data: ", data)
				print(udpstream.get_packet_ip(), ":",udpstream.get_packet_port())
		pass
	
	func _remove_stale():
		for k in pending.keys():
			if pending[k][0] < OS.get_unix_time():
				print("Removing stale")
				pending.erase(k)
	
	func add_pending(id, obj):
		if pending.has(id):
			print("Error, value already in pending!")
			return
		pending[id] = [OS.get_unix_time() + PENDING_TIMEOUT, obj]
	
	func auth(id):
		_remove_stale()
		if pending.has(id):
			var obj = pending[id][1]
			pending.erase(id)
			return obj
		return null
	
	func get_by_obj(obj):
		for c in udpclients:
			if c.client == obj:
				return c
		return null

# Extend this class to create a server handler
class ServerHandler:
	func on_connect(client, stream):
		print_debug("You should extend on_connect(client, stream)")
	
	func on_disconnect(client, stream):
		print_debug("You should override on_disconnect(client, stream)")
	
	func on_message(client, stream, message):
		print_debug("You should override on_message(client, stream, message)")

# Server node
func _ready():
	debug = get_node("../SDebug/Text")

func _exit_tree():
	stop()

func start():
	udpserver = UDPServer.new(port)
	udpserver.handler = self
	server = TCP_Server.new()
	if server.listen( port, ["0.0.0.0"] ) == 0 and udpserver.listen() == 0:
		print_debug("Server started on port "+str(port))
		set_fixed_process( true )
	else:
		print_debug("Failed to start server on port "+str(port))

func set_handler(my_handler):
	if my_handler == null or not my_handler extends ServerHandler:
		print_debug("Invalid handler " + str(my_handler))
		return
	handler = my_handler

func stop():
	if server != null:
		server.stop()

func on_connect(client, stream):
	if handler != null:
		handler.on_connect(client, stream)
	else:
		print_debug("on_connect: Handler not set")

func on_message(client, stream, message):
	if handler != null:
		handler.on_message(client, stream, message)
	else:
		print_debug("on_message: Handler not set")
		print_debug(message)

func on_auth(id, stream, ip, port):
	if stream != null:
		stream.put_var([1, id])
	
	broadcast_udp([101, {name="Faless",ship={"t":9, "l":{}, "p":{1633176173:{"score":0, "ship":{"d":false, "l":0, "ctrl":{"bwd":false, "tr":false, "tl":false, "fwd":false, "lasers":false}, "v":"150,0", "hp":0, "a":0, "r":0, "pos":"915,200"}, "id":1633176173, "name":"Unamed Player"}}, "i":0.1}}])
	#broadcast_udp([101, {"p":{1633176173:{"score":0, "ship":{"d":false, "l":0, "ctrl":{"bwd":false, "tr":false, "tl":false, "fwd":false, "lasers":false}, "v":"150,0", "hp":0, "a":0, "r":0, "pos":"915,200"}, "id":1633176173, "name":"Unamed Player"}}, "i":0.1}.to_json()])
	#broadcast_udp([101, {"p":{1633176173:{"score":0, "ship":{"d":false, "l":0, "ctrl":{"bwd":false, "tr":false, "tl":false}, "v":"150,0", "hp":0, "a":0, "r":0, "pos":"915,200"}, "id":1633176173, "name":"Unamed Player"}}, "i":0.1}])
	#var x = {"a":""}.to_json()
	#print(x.length())
	#print("aaaaaa".length())
	#broadcast_udp([101, "aaaaaaaa"])
	#broadcast_udp([101, x])
	#broadcast_udp(15)
	#broadcast_udp(["a", "b"])
	#broadcast_udp(id)

func broadcast_udp(message):
	for c in udpserver.udpclients:
		udpserver.send_data(message, c.address, c.port)

func on_disconnect(client, stream):
	if handler != null:
		handler.on_disconnect(client, stream)
	else:
		print_debug("on_disconnect: Handler not set")

func _fixed_process(delta):
	# Check new connections
	if server.is_connection_available():
		var client = server.take_connection()
		if clients.size() >= max_conns:
			client.disconnect()
			print_debug("Server is full")
		else:
			clients.append(client)
			streams.append(PacketPeerStream.new())
			var index = clients.find(client)
			streams[index].set_stream_peer(client)
			print_debug("Client has connected! Authenticating UDP stream...")
			send_auth(streams[index])
			on_connect( client, streams[index] )
	# Read incoming data
	for stream in streams:
		while stream.get_available_packet_count() > 0:
			on_message(clients[streams.find(stream)], stream, stream.get_var())
	# Read incoming udp data
	udpserver.process_packets()
	# Delete disconnected clients
	for client in clients:
		if !client.is_connected():
			print_debug("Client disconnected")
			var index = clients.find(client)
			on_disconnect(client, streams[index])
			clients.remove(index)
			streams.remove(index)

func broadcast(message):
	for s in streams:
		s.put_var([2, message])

func send_data(stream, message):
	stream.put_var([2, message])

func send_auth(stream):
	var secret = randi()
	udpserver.add_pending(secret, stream)
	stream.put_var([0, secret])

func validate_auth(client, stream):
	on_connect(client, stream)

func print_debug(mess):
	if debug != null:
		debug.add_text(str(mess))
		debug.newline()
	else:
		print(str(mess))