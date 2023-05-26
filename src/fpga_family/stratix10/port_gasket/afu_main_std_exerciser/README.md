# Default afu\_main\(\)

afu\_main\(\) is the standard module in which AFU-specific logic begins.
The implementation here instantiates a collection of exercisers, attached
to the incoming FIM device interfaces.

AFU development could begin by replacing the contents of afu\_main\(\)
and instantiating the target accelerator.
