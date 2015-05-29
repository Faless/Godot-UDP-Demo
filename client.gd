extends Node

const UDP_TIMEOUT = 10

export var port = 4666
export var ip = "127.0.0.1"

var debug
var handler = null

var conn
var stream
var udpstream
var is_conn = false
var udp_conn = false
var udp_pending = false
var udp_timer = 0
var udp_id = null

class UDPClient:
	const UDP_LIFETIME = 10
	var udpstream = PacketPeerUDP.new()
	var handler = null
	var incoming = {}
	
	func _init(host, port):
		udpstream.set_send_address( host, port )
	
	func send_data(data):
		udpstream.put_var(data)
	
	func close():
		udpstream.close()
	
	func add_incoming(data):
		#print("Received partial message: ", data)
		var id = data[0]
		var c = data[2]
		if not incoming.has(id):
			incoming[id] = [{},OS.get_unix_time() + UDP_LIFETIME]
		incoming[id][0][c] = data[3]
		
	func check_complete(id, len):
		if incoming[id][0].keys().size() == len:
			var s = ""
			for i in range(len):
				s += incoming[id][0][i]
			incoming.erase(id)
			return s
		return null
	
	func process_packets():
		while udpstream.get_available_packet_count() > 0:
			if handler != null:
				#print("Received packets!")
				var data = udpstream.get_var()
				if typeof(data) == TYPE_ARRAY and data.size() == 4 and typeof(data[0]) == TYPE_INT \
						and typeof(data[1]) == TYPE_INT and typeof(data[2]) == TYPE_INT and typeof(data[3]) == TYPE_STRING:
					add_incoming(data)
					var complete = check_complete(data[0], data[1])
					if complete != null:
						handler.on_message(complete)
				else:
					handler.on_message("Unknown UDP data: " + str(data))

func _ready():
	debug = get_node("../CDebug/Text")

func connect():
	#conn = StreamPeerTCP.new()
	#conn.connect( ip, port )
	#stream = PacketPeerStream.new()
	udpstream = UDPClient.new(ip, port)
	udpstream.handler = self
	#stream.set_stream_peer( conn )
	#if conn.get_status() == StreamPeerTCP.STATUS_CONNECTED:
	#	print_debug(  "Connected to "+ip+" :"+str(port) )
	#	set_fixed_process(true)
	#	is_conn = true
	#else:
	#	print_debug("Unable to connect")
	udp_pending = true
	udp_id = 5
	udp_timer = OS.get_unix_time() + UDP_TIMEOUT
	set_fixed_process(true)

func on_message(message):
	print_debug(message)

func _fixed_process(delta):
	# UDP connection pending?
	if udp_pending and udp_timer < OS.get_unix_time():
		# UDP Connection failed
		print("UDP Connection failed, giving up")
		disconnect()
		udp_pending = false
	if udp_pending:
		udp_pending = false
		udpstream.send_data(udp_id)
	# Process UDP packets
	udpstream.process_packets()
	# Parse data
	#while stream.get_available_packet_count() > 0:
	#	var data = stream.get_var()
	#	udp_id = 5
	#	udp_pending = true
	#	udp_timer = OS.get_unix_time() + UDP_TIMEOUT

func print_debug(mess):
	if debug != null:
		debug.add_text(str(mess))
		debug.newline()
	else:
		print(str(mess))