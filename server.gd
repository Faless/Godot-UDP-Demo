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
	
	# We will never send a string longer than this in a single frame
	const PAYLOAD_SIZE = 200
	const PENDING_TIMEOUT = 10
	var udpstream = PacketPeerUDP.new()
	# Outgoing message queue
	var queue = []
	var udpclients = {}
	var pending = {}
	var port
	
	func _init(port):
		self.port = port
	
	func listen():
		return udpstream.listen( port )
	
	func close():
		udpstream.close()
	
	# - Process incoming packets.
	# - Send one queued message (if any).
	func update(delta):
		process_packets()
		if queue.size() > 0:
			udpstream.set_send_address( queue[0].host, queue[0].port )
			udpstream.put_var(queue[0].msg)
			queue.remove(0)
		pass
	
	# Break down the message into smaller packets of size PAYLOAD_SIZE,
	# frame them so client can reconstruct the message, and queue them.
	func send_data(message, host, port):
		var packet = message
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
		while udpstream.get_available_packet_count() > 0:
			var data = udpstream.get_var()
			if typeof(data) == TYPE_INT:
				var k = udpstream.get_packet_ip() + ":" + str(udpstream.get_packet_port())
				if not udpclients.has(k):
					# Adding a new client.
					# We need to store his port and address so we can reply even if client is
					# behind NAT (for at least 2 minutes)
					# see IETF RFC 4787, SECTION 4.3:
					# http://tools.ietf.org/html/rfc4787#section-4.3
					udpclients[k] = {address=udpstream.get_packet_ip(), \
									port=udpstream.get_packet_port() \
								}
					if handler != null and handler.has_method("on_auth"):
						handler.on_auth(data, obj, udpstream.get_packet_ip(), udpstream.get_packet_port())
					print("Added client: ", udpclients[k])
		pass

# Server node
func _ready():
	debug = get_node("../SDebug/Text")

func start():
	udpserver = UDPServer.new(port)
	udpserver.handler = self
	server = TCP_Server.new()
	if server.listen( port, ["0.0.0.0"] ) == 0 and udpserver.listen() == 0:
		print_debug("Server started on port "+str(port))
		set_fixed_process( true )
	else:
		print_debug("Failed to start server on port "+str(port))

func on_auth(id, stream, ip, port):
	if stream != null:
		stream.put_var([1, id])
	broadcast_udp("a_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_very_long_string")

func broadcast_udp(message):
	for c in udpserver.udpclients:
		udpserver.send_data(message, udpserver.udpclients[c].address, udpserver.udpclients[c].port)

func _fixed_process(delta):
	# Check new connections
	if server.is_connection_available():
		var client = server.take_connection()
		clients.append(client)
		streams.append(PacketPeerStream.new())
		var index = clients.find(client)
		streams[index].set_stream_peer(client)
		print_debug("Client has connected! Authenticating UDP stream...")
		streams[index].put_var([0,1])
	# Read incoming udp data
	udpserver.update(delta)

func print_debug(mess):
	if debug != null:
		debug.add_text(str(mess))
		debug.newline()
	else:
		print(str(mess))