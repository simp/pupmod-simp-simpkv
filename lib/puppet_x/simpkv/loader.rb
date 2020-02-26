# Loading this file via 'my_object.instance_eval()' does the following:
# - Adds read and write accessors for a 'simpkv' attribute to 'my_object'.
# - Loads simpkv.rb in a fashion that the anonymous simpkv adapter class it
#   contains is accessible in the scope of this file.
# - Sets the new simpkv attribute of 'my_object' to a new simpkv adapter
#   instance created from the anonymous class.
#
# This code is intended to be loaded by a Puppet catalog instance, so that
# the simpkv adapter can be accessed by all simpkv API functions.  The benefits
# of this circuitous way of accessing the simpkv adapter are:
# - It prevents cross-environment contamination of PuppetX Ruby code
# - It allows new simpkv provider code to be dynamically loaded without
#   a puppetserver reload.
#
################################################################################

# Define attribute accessors

# Get simpkv adapter
# @return simpkv adapter object
def simpkv
  @simpkv
end

# Set simpkv adapter
# @param value simpkv wrapper object
def simpkv=(value)
  @simpkv = value
end

# Load simpkv.rb.  The code evaluated will set this local scope variable
# 'simp_simpkv_adapter_class' to an anonymous Class object for the simpkv adapter
# contained in the file.
# NOTE:  'simp_simpkv_adapter_class' **MUST** be defined prior to the eval
#        in order to be in scope
simp_simpkv_adapter_class = nil
self.instance_eval(
  File.read(File.join(File.dirname(__FILE__), 'simpkv.rb')),
  File.join(File.dirname(__FILE__), 'simpkv.rb')
)

# Set simpkv attribute of the object loading this file to a new simpkv
# adapter instance
self.simpkv = simp_simpkv_adapter_class.new
