<a name="logo"/>
<div align="center">
<img src="./images/pycallrb_logo_200.png" alt="pycall.rb logo" width="200" height="200"></img>
</div>

# PyCall: Calling Python functions from the Ruby language

[![Build Status](https://github.com/mrkn/pycall.rb/workflows/CI/badge.svg)](https://github.com/mrkn/pycall.rb/actions?query=workflow%3ACI)
[![Build Status](https://travis-ci.org/mrkn/pycall.rb.svg?branch=master)](https://travis-ci.org/mrkn/pycall.rb)
[![Build status](https://ci.appveyor.com/api/projects/status/0fad23u4qj1yr49e/branch/master?svg=true)](https://ci.appveyor.com/project/mrkn/pycall-rb/branch/master)

This library provides the features to directly call and partially interoperate
with Python from the Ruby language.  You can import arbitrary Python modules
into Ruby modules, call Python functions with automatic type conversion from
Ruby to Python.

## Supported Ruby versions

pycall.rb supports Ruby version 2.3 or higher.

## Supported Python versions

pycall.rb supports Python version 2.7 or higher.

Note that in Python 2.7 old-style class, that is defined without a super class, is not fully supported in pycall.rb.

## Note for pyenv users

pycall.rb requires Python's shared library (e.g. `libpython3.7m.so`).
pyenv does not build the shared library in default, so you need to specify `--enable-shared` option at the installation like below:

```
$ env PYTHON_CONFIGURE_OPTS='--enable-shared' pyenv install 3.7.2
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'pycall'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install --pre pycall

## Usage

Here is a simple example to call Python's `math.sin` function and compare it to
the `Math.sin` in Ruby:

    require 'pycall/import'
    include PyCall::Import
    pyimport :math
    math.sin(math.pi / 4) - Math.sin(Math::PI / 4)   # => 0.0

Type conversions from Ruby to Python are automatically performed for numeric,
boolean, string, arrays, and hashes.

### Releasing the RubyVM GVL during Python function calls

You may want to release the RubyVM GVL when you call a Python function that takes very long runtime.
PyCall provides `PyCall.without_gvl` method for such purpose.  When PyCall performs python function call,
PyCall checks the current context, and then it releases the RubyVM GVL when the current context is in a `PyCall.without_gvl`'s block.

```ruby
PyCall.without_gvl do
  # In this block, all Python function calls are performed without
  # the GVL acquisition.
  pyobj.long_running_function()
end

# Outside of PyCall.without_gvl block,
# all Python function calls are performed with the GVL acquisition.
pyobj.long_running_function()
```

### Debugging python finder

When you encounter `PyCall::PythonNotFound` error, you can investigate PyCall's python finder by setting `PYCALL_DEBUG_FIND_LIBPYTHON` environment variable to `1`.  You can see the log like below:

```
$ PYCALL_DEBUG_FIND_LIBPYTHON=1 ruby -rpycall -ePyCall.builtins
DEBUG(find_libpython) find_libpython(nil)
DEBUG(find_libpython) investigate_python_config("python3")
DEBUG(find_libpython) libs: ["Python.framework/Versions/3.7/Python", "Python", "libpython3.7m", "libpython3.7", "libpython"]
DEBUG(find_libpython) libpaths: ["/opt/brew/opt/python/Frameworks/Python.framework/Versions/3.7/lib", "/opt/brew/opt/python/lib", "/opt/brew/opt/python/Frameworks", "/opt/brew/Cellar/python/3.7.2_1/Frameworks/Python.framework/Versions/3.7", "/opt/brew/Cellar/python/3.7.2_1/Frameworks/Python.framework/Versions/3.7/lib"]
DEBUG(find_libpython) Unable to find /opt/brew/opt/python/Frameworks/Python.framework/Versions/3.7/lib/Python.framework/Versions/3.7/Python
DEBUG(find_libpython) Unable to find /opt/brew/opt/python/Frameworks/Python.framework/Versions/3.7/lib/Python.framework/Versions/3.7/Python.dylib
DEBUG(find_libpython) Unable to find /opt/brew/opt/python/Frameworks/Python.framework/Versions/3.7/lib/darwin/Python.framework/Versions/3.7/Python
DEBUG(find_libpython) Unable to find /opt/brew/opt/python/Frameworks/Python.framework/Versions/3.7/lib/darwin/Python.framework/Versions/3.7/Python.dylib
DEBUG(find_libpython) Unable to find /opt/brew/opt/python/lib/Python.framework/Versions/3.7/Python
DEBUG(find_libpython) Unable to find /opt/brew/opt/python/lib/Python.framework/Versions/3.7/Python.dylib
DEBUG(find_libpython) Unable to find /opt/brew/opt/python/lib/darwin/Python.framework/Versions/3.7/Python
DEBUG(find_libpython) Unable to find /opt/brew/opt/python/lib/darwin/Python.framework/Versions/3.7/Python.dylib
DEBUG(find_libpython) dlopen("/opt/brew/opt/python/Frameworks/Python.framework/Versions/3.7/Python") = #<Fiddle::Handle:0x00007fc012048650>
```

## PyCall object system

PyCall wraps pointers of Python objects in `PyCall::PyPtr` objects.
`PyCall::PyPtr` class has two subclasses, `PyCall::PyTypePtr` and
`PyCall::PyRubyPtr`.  `PyCall::PyTypePtr` is specialized for type (and classobj
in 2.7) objects, and `PyCall::PyRubyPtr` is for the objects that wraps pointers
of Ruby objects.

These `PyCall::PyPtr` objects are used mainly in PyCall infrastructure.
Instead, we usually treats the instances of `Object`, `Class`, `Module`, or
other classes that are extended by `PyCall::PyObjectWrapper` module.

`PyCall::PyObjectWrapper` is a mix-in module for objects that wraps Python
objects.  A wrapper object should have `PyCall::PyPtr` object in its instance
variable `@__pyptr__`.  `PyCall::PyObjectWrapper` assumes the existance of
`@__pyptr__`, and provides general translation mechanisms between Ruby object
system and Python object system.  For example, `PyCall::PyObjectWrapper`
translates Ruby's coerce system into Python's swapped operation protocol.

### Specifying the Python version

If you want to use a specific version of Python instead of the default,
you can change the Python version by setting the `PYTHON` environment variable
to the path of the `python` executable.

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake spec` to run the tests. You can also run `bin/console`
for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.
To release a new version, update the version number in `version.rb`,
and then run `bundle exec rake release`, which will create a git tag for the
version, push git commits and tags, and push the `.gem` file to
[rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/mrkn/pycall.rb.


## Acknowledgement

[PyCall.jl](https://github.com/JuliaPy/PyCall.jl) is referred too many times
to implement this library.

## License

The gem is available as open source under the terms of the
[MIT License](http://opensource.org/licenses/MIT).
