# The change history of PyCall

## 1.3.0

* Add `PyCall.without_gvl` for explicitly releasing the RubyVM GVL

* Fix for missing if in PyObjectWrapper

  *Kouhei Sutou*

* Fix for Anaconda environment

  *Ryo MATSUMIYA*

* Fix against `unknown symbol "PyInt_AsSsize_t"` (Fiddle::DLError)

  *Kouhei Sutou*

* Fix for `TypeError: Compared with non class/module`

  *Archonic*

## 1.2.1

* Prevent circular require in pycall/iruby.rb

## 1.2.0

* Add `PyCall::Tuple#to_ary`

  *Naoto Takai*

* Release GVL while the Python interpreter is running

* Drop support Ruby 2.2.x and 2.1.x

* Release GVL while the Python interpreter is running [Fix #45]

* Add public header file

* Use PyPtr.none? instead of removed PyCall.none?

  *Kouhei Sutou*

* Export PyObject convert functions

  *Kouhei Sutou*

* Support multiple candidates of Python command in `PyCall.init`

* Now, `PyCall.init` tries `python3` command before `python` in default

* Drop Ruby 2.2 and 2.1 supports

* Add `PyCall::PyTypeObjectWrapper#<` as `Class#<`

* Support class inheritance in python type mapping

## 1.0.3

* Fix anaconda support to define the environment variable `PYTHONHOME`.
  https://github.com/mrkn/pycall.rb/issues/37

## 1.0.2

* Fix the bug that a large Python string is broken when it converted to Ruby string
  https://github.com/mrkn/pycall.rb/issues/32

## 1.0.1

* Add PyTypeObject#===.

## 1.0.0

* `#[]` and `#[]=` accept a `Range` and an `Enumerable`, which is genated by
  `Range#step`, as a slice.

* Rewrite almost all fundamental parts of PyCall as C extension.

* PyCall now calls `Py_DecRef` in the finalizer of `PyCall::PyPtr`.

* Change the system of object mapping between Python and Ruby, drastically.
  Now PyCall does not have `PyObject` class for wrapper objects.
  Instead, PyCall generally makes `Object` instances and extends them by
  `PyObjectWrapper` module.
  But for Python module objects, PyCall makes anonymous `Module` instances 
  that are extended by `PyObjectWrapper` module.
  Moreover for Python type objects, PyCall makes `Class` instances and extends
  them by `PyTypeObjectWrapper` module.

* Change `PyCall.eval` to be a wrapper of `__builtins__.eval` in Python.
  This means that `filename:` and `input_type:` parameters are dropped.
  Instead, two new parameters `globals:` and `locals:` are introduced.
  `globals:` is used for specifying a dictionary that is the global
  namespace referred by the evaluated expression.
  `locals:` is used for specifying a mapping object that is the local
  namespace referred by the evaluated expression.

* Add `PyCall.exec` for the replacement of the former `PyCall.eval`
  with `input_type: :file`.
  It has `globals:` and `locals:` parameters for the same meaning as
  the new `PyCall.eval` described above.

* Drop `PyCall.wrap_ruby_callable` and `PyCall.wrap_ruby_object` always
  craetes a callable Python object taht has an ID of the given Ruby object.
