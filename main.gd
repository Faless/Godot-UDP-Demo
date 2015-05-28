extends Node

func _ready():
	get_node("Server").start()
	get_node("Client").connect()
	pass


