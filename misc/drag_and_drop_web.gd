@tool
extends Node
class_name DragAndDropWeb

signal file_dropped(buffer: PackedByteArray)

var _files_dropped_js_callback := JavaScriptBridge.create_callback(_handle_file_dropped)
var _js_interface: JavaScriptObject

func _handle_file_dropped(_args):
	var buffer: PackedByteArray = JavaScriptBridge.eval("_drop_progressed_buffer", true)
	file_dropped.emit(buffer)

func _init() -> void:
	assert(Global.is_web)
	var _obj = JavaScriptBridge.eval("""
	window.addEventListener("drop", ev => {
		ev.preventDefault();
		for (let file of ev.dataTransfer.files) {
			file.arrayBuffer().then(buffer => {
				window._drop_progressed_buffer = buffer;
				window._drop_callback();
				window._drop_progressed_buffer = null;
			});
		}
	});
	window.addEventListener("dragover", ev => {
		ev.preventDefault();
	});
	window.godotDragAndDropInterface = {
		install: callback => {
			window._drop_callback = callback;
		}
	};
	""")
	_js_interface = JavaScriptBridge.get_interface("godotDragAndDropInterface")
	_js_interface.install(_files_dropped_js_callback)
