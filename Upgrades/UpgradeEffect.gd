extends Resource
class_name UpgradeEffect

enum Operation {
	ADD,
	MULTIPLY,
	SET
}

@export var stat_name: String = ""
@export var operation: Operation = Operation.ADD
@export var value: float = 0.0
