# Batch
Comprehensive Batch Executive

A broad batch executive that facilitates sequencing of tasks on any platform.
The basic premise of the batch executive is to provide for temporal cohesion of
commodity shell-like processing, i.e. invocation of sub-shells, file-handling, 
output-processing and the like.  Perhaps most importantly it will tend to halt
processing if something goes wrong! 

Perl aleady has built-in "die/warn" functions, enhanced via the Carp library.
However, the onus is on the developer to apply these consistently to ensure
the correct processing outcome for any tasks executed.
This module assumes control of these basic operations, such that the caller 
script can focus on its core functionality.

There are several key functions of a batch executive:

 1. Log everything that you do, so you can pin-point a fault.
 2. Fatal error handling: stop if something unexpected happens.
 3. Spawn child processes and account for their outputs.
 4. Provide platform-compatible path-naming for any child shells invoked.
 5. Create, track and remove current and aged temporary files.
 6. File-registration: open and close output files, and report on them.
 7. Convenient handling for directories and common file-formats.
 8. Fail-safe directory manipulation and filesystem privilege assignment.
 9. Common text handling functions, platform determination and behaviour.
10. Provide for basic integration to a scheduling facility.

Such an executive relies on many extant Perl libraries to do much of its 
processing, but wraps consistent handling around their functions.
It also extends the use of these libraries for the most practical defaults
and processsing for all types of batch processing.

As such it simplifies the interface into many lower-level Perl libraries 
in order to make batch processing more reliable and traceable.

