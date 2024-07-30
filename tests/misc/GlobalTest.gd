# GdUnit generated TestSuite
class_name GlobalTest
extends GdUnitTestSuite

# Make sure just in case...
func test_is_in_test() -> void:
	assert_bool(Global.is_in_test).is_true()
