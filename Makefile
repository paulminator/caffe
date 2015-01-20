<<<<<<< HEAD
PROJECT := caffe

CONFIG_FILE := Makefile.config
include $(CONFIG_FILE)

BUILD_DIR_LINK := $(BUILD_DIR)
RELEASE_BUILD_DIR ?= .$(BUILD_DIR)_release
DEBUG_BUILD_DIR ?= .$(BUILD_DIR)_debug

DEBUG ?= 0
ifeq ($(DEBUG), 1)
	BUILD_DIR := $(DEBUG_BUILD_DIR)
	OTHER_BUILD_DIR := $(RELEASE_BUILD_DIR)
else
	BUILD_DIR := $(RELEASE_BUILD_DIR)
	OTHER_BUILD_DIR := $(DEBUG_BUILD_DIR)
endif

# All of the directories containing code.
SRC_DIRS := $(shell find * -type d -exec bash -c "find {} -maxdepth 1 \
	\( -name '*.cpp' -o -name '*.proto' \) | grep -q ." \; -print)

# The target shared library name
LIB_BUILD_DIR := $(BUILD_DIR)/lib
STATIC_NAME := $(LIB_BUILD_DIR)/lib$(PROJECT).a
DYNAMIC_NAME := $(LIB_BUILD_DIR)/lib$(PROJECT).so

##############################
# Get all source files
##############################
# CXX_SRCS are the source files excluding the test ones.
CXX_SRCS := $(shell find src/$(PROJECT) ! -name "test_*.cpp" -name "*.cpp")
# CU_SRCS are the cuda source files
CU_SRCS := $(shell find src/$(PROJECT) ! -name "test_*.cu" -name "*.cu")
# TEST_SRCS are the test source files
TEST_MAIN_SRC := src/$(PROJECT)/test/test_caffe_main.cpp
TEST_SRCS := $(shell find src/$(PROJECT) -name "test_*.cpp")
TEST_SRCS := $(filter-out $(TEST_MAIN_SRC), $(TEST_SRCS))
TEST_CU_SRCS := $(shell find src/$(PROJECT) -name "test_*.cu")
GTEST_SRC := src/gtest/gtest-all.cpp
# TOOL_SRCS are the source files for the tool binaries
TOOL_SRCS := $(shell find tools -name "*.cpp")
# EXAMPLE_SRCS are the source files for the example binaries
EXAMPLE_SRCS := $(shell find examples -name "*.cpp")
# BUILD_INCLUDE_DIR contains any generated header files we want to include.
BUILD_INCLUDE_DIR := $(BUILD_DIR)/src
# PROTO_SRCS are the protocol buffer definitions
PROTO_SRC_DIR := src/$(PROJECT)/proto
PROTO_SRCS := $(wildcard $(PROTO_SRC_DIR)/*.proto)
# PROTO_BUILD_DIR will contain the .cc and obj files generated from
# PROTO_SRCS; PROTO_BUILD_INCLUDE_DIR will contain the .h header files
PROTO_BUILD_DIR := $(BUILD_DIR)/$(PROTO_SRC_DIR)
PROTO_BUILD_INCLUDE_DIR := $(BUILD_INCLUDE_DIR)/$(PROJECT)/proto
# NONGEN_CXX_SRCS includes all source/header files except those generated
# automatically (e.g., by proto).
NONGEN_CXX_SRCS := $(shell find \
	src/$(PROJECT) \
	include/$(PROJECT) \
	python/$(PROJECT) \
	matlab/$(PROJECT) \
	examples \
	tools \
	-name "*.cpp" -or -name "*.hpp" -or -name "*.cu" -or -name "*.cuh")
LINT_SCRIPT := scripts/cpp_lint.py
LINT_OUTPUT_DIR := $(BUILD_DIR)/.lint
LINT_EXT := lint.txt
LINT_OUTPUTS := $(addsuffix .$(LINT_EXT), $(addprefix $(LINT_OUTPUT_DIR)/, $(NONGEN_CXX_SRCS)))
EMPTY_LINT_REPORT := $(BUILD_DIR)/.$(LINT_EXT)
NONEMPTY_LINT_REPORT := $(BUILD_DIR)/$(LINT_EXT)
# PY$(PROJECT)_SRC is the python wrapper for $(PROJECT)
PY$(PROJECT)_SRC := python/$(PROJECT)/_$(PROJECT).cpp
PY$(PROJECT)_HXX_SRC := python/$(PROJECT)/_$(PROJECT).hpp
PY$(PROJECT)_SO := python/$(PROJECT)/_$(PROJECT).so
# MAT$(PROJECT)_SRC is the matlab wrapper for $(PROJECT)
MAT$(PROJECT)_SRC := matlab/$(PROJECT)/mat$(PROJECT).cpp
ifneq ($(MATLAB_DIR),)
	MAT_SO_EXT := $(shell $(MATLAB_DIR)/bin/mexext)
endif
MAT$(PROJECT)_SO := matlab/$(PROJECT)/$(PROJECT).$(MAT_SO_EXT)

##############################
# Derive generated files
##############################
# The generated files for protocol buffers
PROTO_GEN_HEADER_SRCS := $(addprefix $(PROTO_BUILD_DIR)/, \
		$(notdir ${PROTO_SRCS:.proto=.pb.h}))
PROTO_GEN_HEADER := $(addprefix $(PROTO_BUILD_INCLUDE_DIR)/, \
		$(notdir ${PROTO_SRCS:.proto=.pb.h}))
PROTO_GEN_CC := $(addprefix $(BUILD_DIR)/, ${PROTO_SRCS:.proto=.pb.cc})
PY_PROTO_BUILD_DIR := python/$(PROJECT)/proto
PY_PROTO_INIT := python/$(PROJECT)/proto/__init__.py
PROTO_GEN_PY := $(foreach file,${PROTO_SRCS:.proto=_pb2.py}, \
		$(PY_PROTO_BUILD_DIR)/$(notdir $(file)))
# The objects corresponding to the source files
# These objects will be linked into the final shared library, so we
# exclude the tool, example, and test objects.
CXX_OBJS := $(addprefix $(BUILD_DIR)/, ${CXX_SRCS:.cpp=.o})
CU_OBJS := $(addprefix $(BUILD_DIR)/cuda/, ${CU_SRCS:.cu=.o})
PROTO_OBJS := ${PROTO_GEN_CC:.cc=.o}
OBJS := $(PROTO_OBJS) $(CXX_OBJS) $(CU_OBJS)
# tool, example, and test objects
TOOL_OBJS := $(addprefix $(BUILD_DIR)/, ${TOOL_SRCS:.cpp=.o})
TOOL_BUILD_DIR := $(BUILD_DIR)/tools
TEST_CXX_BUILD_DIR := $(BUILD_DIR)/src/$(PROJECT)/test
TEST_CU_BUILD_DIR := $(BUILD_DIR)/cuda/src/$(PROJECT)/test
TEST_CXX_OBJS := $(addprefix $(BUILD_DIR)/, ${TEST_SRCS:.cpp=.o})
TEST_CU_OBJS := $(addprefix $(BUILD_DIR)/cuda/, ${TEST_CU_SRCS:.cu=.o})
TEST_OBJS := $(TEST_CXX_OBJS) $(TEST_CU_OBJS)
GTEST_OBJ := $(addprefix $(BUILD_DIR)/, ${GTEST_SRC:.cpp=.o})
EXAMPLE_OBJS := $(addprefix $(BUILD_DIR)/, ${EXAMPLE_SRCS:.cpp=.o})
# Output files for automatic dependency generation
DEPS := ${CXX_OBJS:.o=.d} ${CU_OBJS:.o=.d} ${TEST_CXX_OBJS:.o=.d} \
	${TEST_CU_OBJS:.o=.d}
# tool, example, and test bins
TOOL_BINS := ${TOOL_OBJS:.o=.bin}
EXAMPLE_BINS := ${EXAMPLE_OBJS:.o=.bin}
# symlinks to tool bins without the ".bin" extension
TOOL_BIN_LINKS := ${TOOL_BINS:.bin=}
# Put the test binaries in build/test for convenience.
TEST_BIN_DIR := $(BUILD_DIR)/test
TEST_CU_BINS := $(addsuffix .testbin,$(addprefix $(TEST_BIN_DIR)/, \
		$(foreach obj,$(TEST_CU_OBJS),$(basename $(notdir $(obj))))))
TEST_CXX_BINS := $(addsuffix .testbin,$(addprefix $(TEST_BIN_DIR)/, \
		$(foreach obj,$(TEST_CXX_OBJS),$(basename $(notdir $(obj))))))
TEST_BINS := $(TEST_CXX_BINS) $(TEST_CU_BINS)
# TEST_ALL_BIN is the test binary that links caffe statically.
TEST_ALL_BIN := $(TEST_BIN_DIR)/test_all.testbin
# TEST_ALL_DYNINK_BIN is the test binary that links caffe as a dynamic library.
TEST_ALL_DYNLINK_BIN := $(TEST_BIN_DIR)/test_all_dynamic_link.testbin

##############################
# Derive compiler warning dump locations
##############################
WARNS_EXT := warnings.txt
CXX_WARNS := $(addprefix $(BUILD_DIR)/, ${CXX_SRCS:.cpp=.o.$(WARNS_EXT)})
CU_WARNS := $(addprefix $(BUILD_DIR)/cuda/, ${CU_SRCS:.cu=.o.$(WARNS_EXT)})
TOOL_WARNS := $(addprefix $(BUILD_DIR)/, ${TOOL_SRCS:.cpp=.o.$(WARNS_EXT)})
EXAMPLE_WARNS := $(addprefix $(BUILD_DIR)/, ${EXAMPLE_SRCS:.cpp=.o.$(WARNS_EXT)})
TEST_WARNS := $(addprefix $(BUILD_DIR)/, ${TEST_SRCS:.cpp=.o.$(WARNS_EXT)})
TEST_CU_WARNS := $(addprefix $(BUILD_DIR)/cuda/, ${TEST_CU_SRCS:.cu=.o.$(WARNS_EXT)})
ALL_CXX_WARNS := $(CXX_WARNS) $(TOOL_WARNS) $(EXAMPLE_WARNS) $(TEST_WARNS)
ALL_CU_WARNS := $(CU_WARNS) $(TEST_CU_WARNS)
ALL_WARNS := $(ALL_CXX_WARNS) $(ALL_CU_WARNS)

EMPTY_WARN_REPORT := $(BUILD_DIR)/.$(WARNS_EXT)
NONEMPTY_WARN_REPORT := $(BUILD_DIR)/$(WARNS_EXT)

##############################
# Derive include and lib directories
##############################
CUDA_INCLUDE_DIR := $(CUDA_DIR)/include

CUDA_LIB_DIR :=
# add <cuda>/lib64 only if it exists
ifneq ("$(wildcard $(CUDA_DIR)/lib64)","")
	CUDA_LIB_DIR += $(CUDA_DIR)/lib64
endif
CUDA_LIB_DIR += $(CUDA_DIR)/lib

INCLUDE_DIRS += $(BUILD_INCLUDE_DIR) ./src ./include
ifneq ($(CPU_ONLY), 1)
	INCLUDE_DIRS += $(CUDA_INCLUDE_DIR)
	LIBRARY_DIRS += $(CUDA_LIB_DIR)
	LIBRARIES := cudart cublas curand
endif
LIBRARIES += glog gflags protobuf leveldb snappy \
	lmdb boost_system hdf5_hl hdf5 m \
	opencv_core opencv_highgui opencv_imgproc
PYTHON_LIBRARIES := boost_python python2.7
WARNINGS := -Wall -Wno-sign-compare

##############################
# Set build directories
##############################

DISTRIBUTE_SUBDIRS := $(DISTRIBUTE_DIR)/bin $(DISTRIBUTE_DIR)/lib
DIST_ALIASES := dist
ifneq ($(strip $(DISTRIBUTE_DIR)),distribute)
		DIST_ALIASES += distribute
endif

ALL_BUILD_DIRS := $(sort $(BUILD_DIR) $(addprefix $(BUILD_DIR)/, $(SRC_DIRS)) \
	$(addprefix $(BUILD_DIR)/cuda/, $(SRC_DIRS)) \
	$(LIB_BUILD_DIR) $(TEST_BIN_DIR) $(PY_PROTO_BUILD_DIR) $(LINT_OUTPUT_DIR) \
	$(DISTRIBUTE_SUBDIRS) $(PROTO_BUILD_INCLUDE_DIR))

##############################
# Set directory for Doxygen-generated documentation
##############################
DOXYGEN_CONFIG_FILE ?= ./.Doxyfile
# should be the same as OUTPUT_DIRECTORY in the .Doxyfile
DOXYGEN_OUTPUT_DIR ?= ./doxygen
DOXYGEN_COMMAND ?= doxygen
# All the files that might have Doxygen documentation.
DOXYGEN_SOURCES := $(shell find \
	src/$(PROJECT) \
	include/$(PROJECT) \
	python/ \
	matlab/ \
	examples \
	tools \
	-name "*.cpp" -or -name "*.hpp" -or -name "*.cu" -or -name "*.cuh" -or \
        -name "*.py" -or -name "*.m")
DOXYGEN_SOURCES += $(DOXYGEN_CONFIG_FILE)


##############################
# Configure build
##############################

# Determine platform
UNAME := $(shell uname -s)
ifeq ($(UNAME), Linux)
	LINUX := 1
else ifeq ($(UNAME), Darwin)
	OSX := 1
endif

# Linux
ifeq ($(LINUX), 1)
	CXX ?= /usr/bin/g++
	GCCVERSION := $(shell $(CXX) -dumpversion | cut -f1,2 -d.)
	# older versions of gcc are too dumb to build boost with -Wuninitalized
	ifeq ($(shell echo $(GCCVERSION) \< 4.6 | bc), 1)
		WARNINGS += -Wno-uninitialized
	endif
	# boost::thread is reasonably called boost_thread (compare OS X)
	# We will also explicitly add stdc++ to the link target.
	LIBRARIES += boost_thread stdc++
endif

# OS X:
# clang++ instead of g++
# libstdc++ instead of libc++ for CUDA compatibility on 10.9
ifeq ($(OSX), 1)
	CXX := /usr/bin/clang++
	CXXFLAGS += -stdlib=libstdc++
	LINKFLAGS += -stdlib=libstdc++
	# clang throws this warning for cuda headers
	WARNINGS += -Wno-unneeded-internal-declaration
	# gtest needs to use its own tuple to not conflict with clang
	CXXFLAGS += -DGTEST_USE_OWN_TR1_TUPLE=1
	# boost::thread is called boost_thread-mt to mark multithreading on OS X
	LIBRARIES += boost_thread-mt
endif

# Custom compiler
ifdef CUSTOM_CXX
	CXX := $(CUSTOM_CXX)
endif

# Static linking
ifneq (,$(findstring clang++,$(CXX)))
	STATIC_LINK_COMMAND := -Wl,-force_load $(STATIC_NAME)
else ifneq (,$(findstring g++,$(CXX)))
	STATIC_LINK_COMMAND := -Wl,--whole-archive $(STATIC_NAME) -Wl,--no-whole-archive
else
	$(error Cannot static link with the $(CXX) compiler.)
endif

# Debugging
ifeq ($(DEBUG), 1)
	COMMON_FLAGS += -DDEBUG -g -O0
	NVCCFLAGS += -G
else
	COMMON_FLAGS += -DNDEBUG -O2
endif

# cuDNN acceleration configuration.
ifeq ($(USE_CUDNN), 1)
	LIBRARIES += cudnn
	COMMON_FLAGS += -DUSE_CUDNN
endif

# CPU-only configuration
ifeq ($(CPU_ONLY), 1)
	OBJS := $(PROTO_OBJS) $(CXX_OBJS)
	TEST_OBJS := $(TEST_CXX_OBJS)
	TEST_BINS := $(TEST_CXX_BINS)
	ALL_WARNS := $(ALL_CXX_WARNS)
	TEST_FILTER := --gtest_filter="-*GPU*"
	COMMON_FLAGS += -DCPU_ONLY
endif

# BLAS configuration (default = ATLAS)
BLAS ?= atlas
ifeq ($(BLAS), mkl)
	# MKL
	LIBRARIES += mkl_rt
	COMMON_FLAGS += -DUSE_MKL
	MKL_DIR ?= /opt/intel/mkl
	BLAS_INCLUDE ?= $(MKL_DIR)/include
	BLAS_LIB ?= $(MKL_DIR)/lib $(MKL_DIR)/lib/intel64
else ifeq ($(BLAS), open)
	# OpenBLAS
	LIBRARIES += openblas
else
	# ATLAS
	ifeq ($(LINUX), 1)
		ifeq ($(BLAS), atlas)
			# Linux simply has cblas and atlas
			LIBRARIES += cblas atlas
		endif
	else ifeq ($(OSX), 1)
		# OS X packages atlas as the vecLib framework
		LIBRARIES += cblas
		# 10.10 has accelerate while 10.9 has veclib
		XCODE_CLT_VER := $(shell pkgutil --pkg-info=com.apple.pkg.CLTools_Executables | grep -o 'version: 6')
		ifneq (,$(findstring version: 6,$(XCODE_CLT_VER)))
			BLAS_INCLUDE ?= /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk/System/Library/Frameworks/Accelerate.framework/Versions/Current/Frameworks/vecLib.framework/Headers/
			LDFLAGS += -framework Accelerate
		else
			BLAS_INCLUDE ?= /System/Library/Frameworks/vecLib.framework/Versions/Current/Headers/
			LDFLAGS += -framework vecLib
		endif
	endif
endif
INCLUDE_DIRS += $(BLAS_INCLUDE)
LIBRARY_DIRS += $(BLAS_LIB)

LIBRARY_DIRS += $(LIB_BUILD_DIR)

# Automatic dependency generation (nvcc is handled separately)
CXXFLAGS += -MMD -MP

# Complete build flags.
COMMON_FLAGS += $(foreach includedir,$(INCLUDE_DIRS),-I$(includedir))
CXXFLAGS += -pthread -fPIC $(COMMON_FLAGS) $(WARNINGS)
NVCCFLAGS += -ccbin=$(CXX) -Xcompiler -fPIC $(COMMON_FLAGS)
# mex may invoke an older gcc that is too liberal with -Wuninitalized
MATLAB_CXXFLAGS := $(CXXFLAGS) -Wno-uninitialized
LINKFLAGS += -pthread -fPIC $(COMMON_FLAGS) $(WARNINGS)

USE_PKG_CONFIG ?= 0
ifeq ($(USE_PKG_CONFIG), 1)
	PKG_CONFIG := $(shell pkg-config opencv --libs)
else
	PKG_CONFIG :=
endif
LDFLAGS += $(foreach librarydir,$(LIBRARY_DIRS),-L$(librarydir)) $(PKG_CONFIG) \
		$(foreach library,$(LIBRARIES),-l$(library))
PYTHON_LDFLAGS := $(LDFLAGS) $(foreach library,$(PYTHON_LIBRARIES),-l$(library))
DYNAMIC_LDFLAGS := -l$(PROJECT) -Wl,-rpath,\$$ORIGIN/../lib

# 'superclean' target recursively* deletes all files ending with an extension
# in $(SUPERCLEAN_EXTS) below.  This may be useful if you've built older
# versions of Caffe that do not place all generated files in a location known
# to the 'clean' target.
#
# 'supercleanlist' will list the files to be deleted by make superclean.
#
# * Recursive with the exception that symbolic links are never followed, per the
# default behavior of 'find'.
SUPERCLEAN_EXTS := .so .a .o .bin .testbin .pb.cc .pb.h _pb2.py .cuo

# Set the sub-targets of the 'everything' target.
EVERYTHING_TARGETS := all py$(PROJECT) test warn lint
# Only build matcaffe as part of "everything" if MATLAB_DIR is specified.
ifneq ($(MATLAB_DIR),)
	EVERYTHING_TARGETS += mat$(PROJECT)
endif

##############################
# Define build targets
##############################
.PHONY: all test clean docs linecount lint lintclean tools examples $(DIST_ALIASES) \
	py mat py$(PROJECT) mat$(PROJECT) proto runtest \
	superclean supercleanlist supercleanfiles warn everything

all: $(STATIC_NAME) $(DYNAMIC_NAME) tools examples

everything: $(EVERYTHING_TARGETS)

linecount:
	cloc --read-lang-def=$(PROJECT).cloc \
		src/$(PROJECT) include/$(PROJECT) tools examples \
		python matlab

lint: $(EMPTY_LINT_REPORT)

lintclean:
	@ $(RM) -r $(LINT_OUTPUT_DIR) $(EMPTY_LINT_REPORT) $(NONEMPTY_LINT_REPORT)

docs: $(DOXYGEN_OUTPUT_DIR)
	@ cd ./docs ; ln -sfn ../$(DOXYGEN_OUTPUT_DIR)/html doxygen

$(DOXYGEN_OUTPUT_DIR): $(DOXYGEN_CONFIG_FILE) $(DOXYGEN_SOURCES)
	$(DOXYGEN_COMMAND) $(DOXYGEN_CONFIG_FILE)

$(EMPTY_LINT_REPORT): $(LINT_OUTPUTS) | $(BUILD_DIR)
	@ cat $(LINT_OUTPUTS) > $@
	@ if [ -s "$@" ]; then \
		cat $@; \
		mv $@ $(NONEMPTY_LINT_REPORT); \
		echo "Found one or more lint errors."; \
		exit 1; \
	  fi; \
	  $(RM) $(NONEMPTY_LINT_REPORT); \
	  echo "No lint errors!";

$(LINT_OUTPUTS): $(LINT_OUTPUT_DIR)/%.lint.txt : % $(LINT_SCRIPT) | $(LINT_OUTPUT_DIR)
	@ mkdir -p $(dir $@)
	@ python $(LINT_SCRIPT) $< 2>&1 \
		| grep -v "^Done processing " \
		| grep -v "^Total errors found: 0" \
		> $@ \
		|| true

test: $(TEST_ALL_BIN) $(TEST_ALL_DYNLINK_BIN) $(TEST_BINS)

tools: $(TOOL_BINS) $(TOOL_BIN_LINKS)

examples: $(EXAMPLE_BINS)

py$(PROJECT): py

py: $(PY$(PROJECT)_SO) $(PROTO_GEN_PY)

$(PY$(PROJECT)_SO): $(PY$(PROJECT)_SRC) $(STATIC_NAME) $(PY$(PROJECT)_HXX_SRC)
	@ echo CXX $<
	$(Q)$(CXX) -shared -o $@ $(PY$(PROJECT)_SRC) \
		$(STATIC_LINK_COMMAND) $(LINKFLAGS) $(PYTHON_LDFLAGS)

mat$(PROJECT): mat

mat: $(MAT$(PROJECT)_SO)

$(MAT$(PROJECT)_SO): $(MAT$(PROJECT)_SRC) $(STATIC_NAME)
	@ if [ -z "$(MATLAB_DIR)" ]; then \
		echo "MATLAB_DIR must be specified in $(CONFIG_FILE)" \
			"to build mat$(PROJECT)."; \
		exit 1; \
	fi
	@ echo MEX $<
	$(Q)$(MATLAB_DIR)/bin/mex $(MAT$(PROJECT)_SRC) \
			CXX="$(CXX)" \
			CXXFLAGS="\$$CXXFLAGS $(MATLAB_CXXFLAGS)" \
			CXXLIBS="\$$CXXLIBS $(STATIC_LINK_COMMAND) $(LDFLAGS)" -output $@

runtest: $(TEST_ALL_BIN) $(TEST_ALL_DYNLINK_BIN)
	$(TEST_ALL_BIN) $(TEST_GPUID) --gtest_shuffle $(TEST_FILTER) && \
	$(TEST_ALL_DYNLINK_BIN) $(TEST_GPUID) --gtest_shuffle $(TEST_FILTER)

warn: $(EMPTY_WARN_REPORT)

$(EMPTY_WARN_REPORT): $(ALL_WARNS) | $(BUILD_DIR)
	@ cat $(ALL_WARNS) > $@
	@ if [ -s "$@" ]; then \
		cat $@; \
		mv $@ $(NONEMPTY_WARN_REPORT); \
		echo "Compiler produced one or more warnings."; \
		exit 1; \
	  fi; \
	  $(RM) $(NONEMPTY_WARN_REPORT); \
	  echo "No compiler warnings!";

$(ALL_WARNS): %.o.$(WARNS_EXT) : %.o

$(BUILD_DIR_LINK): $(BUILD_DIR)/.linked

# Create a target ".linked" in this BUILD_DIR to tell Make that the "build" link
# is currently correct, then delete the one in the OTHER_BUILD_DIR in case it
# exists and $(DEBUG) is toggled later.
$(BUILD_DIR)/.linked:
	@ mkdir -p $(BUILD_DIR)
	@ $(RM) $(OTHER_BUILD_DIR)/.linked
	@ $(RM) -r $(BUILD_DIR_LINK)
	@ ln -s $(BUILD_DIR) $(BUILD_DIR_LINK)
	@ touch $@

$(ALL_BUILD_DIRS): | $(BUILD_DIR_LINK)
	@ mkdir -p $@

$(DYNAMIC_NAME): $(OBJS) | $(LIB_BUILD_DIR)
	@ echo LD -o $@
	$(Q)$(CXX) -shared -o $@ $(OBJS) $(LINKFLAGS) $(LDFLAGS)

$(STATIC_NAME): $(OBJS) | $(LIB_BUILD_DIR)
	@ echo AR -o $@
	$(Q)ar rcs $@ $(OBJS)

$(BUILD_DIR)/%.o: %.cpp | $(ALL_BUILD_DIRS)
	@ echo CXX $<
	$(Q)$(CXX) $< $(CXXFLAGS) -c -o $@ 2> $@.$(WARNS_EXT) \
		|| (cat $@.$(WARNS_EXT); exit 1)
	@ cat $@.$(WARNS_EXT)

$(PROTO_BUILD_DIR)/%.pb.o: $(PROTO_BUILD_DIR)/%.pb.cc $(PROTO_GEN_HEADER) \
		| $(PROTO_BUILD_DIR)
	@ echo CXX $<
	$(Q)$(CXX) $< $(CXXFLAGS) -c -o $@ 2> $@.$(WARNS_EXT) \
		|| (cat $@.$(WARNS_EXT); exit 1)
	@ cat $@.$(WARNS_EXT)

$(BUILD_DIR)/cuda/%.o: %.cu | $(ALL_BUILD_DIRS)
	@ echo NVCC $<
	$(Q)$(CUDA_DIR)/bin/nvcc $(NVCCFLAGS) $(CUDA_ARCH) -M $< -o ${@:.o=.d} \
		-odir $(@D)
	$(Q)$(CUDA_DIR)/bin/nvcc $(NVCCFLAGS) $(CUDA_ARCH) -c $< -o $@ 2> $@.$(WARNS_EXT) \
		|| (cat $@.$(WARNS_EXT); exit 1)
	@ cat $@.$(WARNS_EXT)

$(TEST_ALL_BIN): $(TEST_MAIN_SRC) $(TEST_OBJS) $(GTEST_OBJ) $(STATIC_NAME) \
		| $(TEST_BIN_DIR)
	@ echo CXX/LD -o $@ $<
	$(Q)$(CXX) $(TEST_MAIN_SRC) $(TEST_OBJS) $(GTEST_OBJ) $(STATIC_LINK_COMMAND) \
		-o $@ $(LINKFLAGS) $(LDFLAGS)

$(TEST_ALL_DYNLINK_BIN): $(TEST_MAIN_SRC) $(TEST_OBJS) $(GTEST_OBJ) $(DYNAMIC_NAME) \
		| $(TEST_BIN_DIR)
	@ echo CXX/LD -o $@ $<
	$(Q)$(CXX) $(TEST_MAIN_SRC) $(TEST_OBJS) $(GTEST_OBJ) \
		-o $@ $(LINKFLAGS) $(LDFLAGS) $(DYNAMIC_LDFLAGS)

$(TEST_CU_BINS): $(TEST_BIN_DIR)/%.testbin: $(TEST_CU_BUILD_DIR)/%.o \
	$(GTEST_OBJ) $(STATIC_NAME) | $(TEST_BIN_DIR)
	@ echo LD $<
	$(Q)$(CXX) $(TEST_MAIN_SRC) $< $(GTEST_OBJ) $(STATIC_LINK_COMMAND) \
		-o $@ $(LINKFLAGS) $(LDFLAGS)

$(TEST_CXX_BINS): $(TEST_BIN_DIR)/%.testbin: $(TEST_CXX_BUILD_DIR)/%.o \
	$(GTEST_OBJ) $(STATIC_NAME) | $(TEST_BIN_DIR)
	@ echo LD $<
	$(Q)$(CXX) $(TEST_MAIN_SRC) $< $(GTEST_OBJ) $(STATIC_LINK_COMMAND) \
		-o $@ $(LINKFLAGS) $(LDFLAGS)

# Target for extension-less symlinks to tool binaries with extension '*.bin'.
$(TOOL_BUILD_DIR)/%: $(TOOL_BUILD_DIR)/%.bin | $(TOOL_BUILD_DIR)
	@ $(RM) $@
	@ ln -s $(abspath $<) $@

$(TOOL_BINS) $(EXAMPLE_BINS): %.bin : %.o $(STATIC_NAME)
	@ echo LD $<
	$(Q)$(CXX) $< $(STATIC_LINK_COMMAND) -o $@ $(LINKFLAGS) $(LDFLAGS)

proto: $(PROTO_GEN_CC) $(PROTO_GEN_HEADER)

$(PROTO_BUILD_DIR)/%.pb.cc $(PROTO_BUILD_DIR)/%.pb.h : \
		$(PROTO_SRC_DIR)/%.proto | $(PROTO_BUILD_DIR)
	@ echo PROTOC $<
	$(Q)protoc --proto_path=$(PROTO_SRC_DIR) --cpp_out=$(PROTO_BUILD_DIR) $<

$(PY_PROTO_BUILD_DIR)/%_pb2.py : $(PROTO_SRC_DIR)/%.proto \
		$(PY_PROTO_INIT) | $(PY_PROTO_BUILD_DIR)
	@ echo PROTOC \(python\) $<
	$(Q)protoc --proto_path=$(PROTO_SRC_DIR) --python_out=$(PY_PROTO_BUILD_DIR) $<

$(PY_PROTO_INIT): | $(PY_PROTO_BUILD_DIR)
	touch $(PY_PROTO_INIT)
=======
# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 2.8
>>>>>>> ''

# Default target executed when no arguments are given to make.
default_target: all
.PHONY : default_target

#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:

# Remove some rules from gmake that .SUFFIXES does not remove.
SUFFIXES =

.SUFFIXES: .hpux_make_needs_suffix_list

# Suppress display of executed commands.
$(VERBOSE).SILENT:

# A target that is always out of date.
cmake_force:
.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/bin/cmake

# The command to remove a file.
RM = /usr/bin/cmake -E remove -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /home/me/caffe

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /home/me/caffe

#=============================================================================
# Targets provided globally by CMake.

# Special rule for the target edit_cache
edit_cache:
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --cyan "Running interactive CMake command-line interface..."
	/usr/bin/cmake -i .
.PHONY : edit_cache

# Special rule for the target edit_cache
edit_cache/fast: edit_cache
.PHONY : edit_cache/fast

# Special rule for the target install
install: preinstall
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --cyan "Install the project..."
	/usr/bin/cmake -P cmake_install.cmake
.PHONY : install

# Special rule for the target install
install/fast: preinstall/fast
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --cyan "Install the project..."
	/usr/bin/cmake -P cmake_install.cmake
.PHONY : install/fast

# Special rule for the target install/local
install/local: preinstall
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --cyan "Installing only the local directory..."
	/usr/bin/cmake -DCMAKE_INSTALL_LOCAL_ONLY=1 -P cmake_install.cmake
.PHONY : install/local

# Special rule for the target install/local
install/local/fast: install/local
.PHONY : install/local/fast

# Special rule for the target install/strip
install/strip: preinstall
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --cyan "Installing the project stripped..."
	/usr/bin/cmake -DCMAKE_INSTALL_DO_STRIP=1 -P cmake_install.cmake
.PHONY : install/strip

# Special rule for the target install/strip
install/strip/fast: install/strip
.PHONY : install/strip/fast

# Special rule for the target list_install_components
list_install_components:
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --cyan "Available install components are: \"Unspecified\""
.PHONY : list_install_components

# Special rule for the target list_install_components
list_install_components/fast: list_install_components
.PHONY : list_install_components/fast

# Special rule for the target rebuild_cache
rebuild_cache:
	@$(CMAKE_COMMAND) -E cmake_echo_color --switch=$(COLOR) --cyan "Running CMake to regenerate build system..."
	/usr/bin/cmake -H$(CMAKE_SOURCE_DIR) -B$(CMAKE_BINARY_DIR)
.PHONY : rebuild_cache

# Special rule for the target rebuild_cache
rebuild_cache/fast: rebuild_cache
.PHONY : rebuild_cache/fast

# The main all target
all: cmake_check_build_system
	$(CMAKE_COMMAND) -E cmake_progress_start /home/me/caffe/CMakeFiles /home/me/caffe/CMakeFiles/progress.marks
	$(MAKE) -f CMakeFiles/Makefile2 all
	$(CMAKE_COMMAND) -E cmake_progress_start /home/me/caffe/CMakeFiles 0
.PHONY : all

# The main clean target
clean:
<<<<<<< HEAD
	@- $(RM) -rf $(ALL_BUILD_DIRS)
	@- $(RM) -rf $(OTHER_BUILD_DIR)
	@- $(RM) -rf $(BUILD_DIR_LINK)
	@- $(RM) -rf $(DISTRIBUTE_DIR)
	@- $(RM) $(PY$(PROJECT)_SO)
	@- $(RM) $(MAT$(PROJECT)_SO)

supercleanfiles:
	$(eval SUPERCLEAN_FILES := $(strip \
			$(foreach ext,$(SUPERCLEAN_EXTS), $(shell find . -name '*$(ext)' \
			-not -path './data/*'))))

supercleanlist: supercleanfiles
	@ \
	if [ -z "$(SUPERCLEAN_FILES)" ]; then \
		echo "No generated files found."; \
	else \
		echo $(SUPERCLEAN_FILES) | tr ' ' '\n'; \
	fi

superclean: clean supercleanfiles
	@ \
	if [ -z "$(SUPERCLEAN_FILES)" ]; then \
		echo "No generated files found."; \
	else \
		echo "Deleting the following generated files:"; \
		echo $(SUPERCLEAN_FILES) | tr ' ' '\n'; \
		$(RM) $(SUPERCLEAN_FILES); \
	fi

$(DIST_ALIASES): $(DISTRIBUTE_DIR)

$(DISTRIBUTE_DIR): all py | $(DISTRIBUTE_SUBDIRS)
	# add include
	cp -r include $(DISTRIBUTE_DIR)/
	mkdir -p $(DISTRIBUTE_DIR)/include/caffe/proto
	cp $(PROTO_GEN_HEADER_SRCS) $(DISTRIBUTE_DIR)/include/caffe/proto
	# add tool and example binaries
	cp $(TOOL_BINS) $(DISTRIBUTE_DIR)/bin
	cp $(EXAMPLE_BINS) $(DISTRIBUTE_DIR)/bin
	# add libraries
	cp $(STATIC_NAME) $(DISTRIBUTE_DIR)/lib
	cp $(DYNAMIC_NAME) $(DISTRIBUTE_DIR)/lib
	# add python - it's not the standard way, indeed...
	cp -r python $(DISTRIBUTE_DIR)/python

-include $(DEPS)
=======
	$(MAKE) -f CMakeFiles/Makefile2 clean
.PHONY : clean

# The main clean target
clean/fast: clean
.PHONY : clean/fast

# Prepare targets for installation.
preinstall: all
	$(MAKE) -f CMakeFiles/Makefile2 preinstall
.PHONY : preinstall

# Prepare targets for installation.
preinstall/fast:
	$(MAKE) -f CMakeFiles/Makefile2 preinstall
.PHONY : preinstall/fast

# clear depends
depend:
	$(CMAKE_COMMAND) -H$(CMAKE_SOURCE_DIR) -B$(CMAKE_BINARY_DIR) --check-build-system CMakeFiles/Makefile.cmake 1
.PHONY : depend

#=============================================================================
# Target rules for targets named lint

# Build rule for target.
lint: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 lint
.PHONY : lint

# fast build rule for target.
lint/fast:
	$(MAKE) -f CMakeFiles/lint.dir/build.make CMakeFiles/lint.dir/build
.PHONY : lint/fast

#=============================================================================
# Target rules for targets named gtest

# Build rule for target.
gtest: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 gtest
.PHONY : gtest

# fast build rule for target.
gtest/fast:
	$(MAKE) -f src/gtest/CMakeFiles/gtest.dir/build.make src/gtest/CMakeFiles/gtest.dir/build
.PHONY : gtest/fast

#=============================================================================
# Target rules for targets named gtest_main

# Build rule for target.
gtest_main: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 gtest_main
.PHONY : gtest_main

# fast build rule for target.
gtest_main/fast:
	$(MAKE) -f src/gtest/CMakeFiles/gtest_main.dir/build.make src/gtest/CMakeFiles/gtest_main.dir/build
.PHONY : gtest_main/fast

#=============================================================================
# Target rules for targets named caffe

# Build rule for target.
caffe: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 caffe
.PHONY : caffe

# fast build rule for target.
caffe/fast:
	$(MAKE) -f src/caffe/CMakeFiles/caffe.dir/build.make src/caffe/CMakeFiles/caffe.dir/build
.PHONY : caffe/fast

#=============================================================================
# Target rules for targets named caffe_cu

# Build rule for target.
caffe_cu: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 caffe_cu
.PHONY : caffe_cu

# fast build rule for target.
caffe_cu/fast:
	$(MAKE) -f src/caffe/CMakeFiles/caffe_cu.dir/build.make src/caffe/CMakeFiles/caffe_cu.dir/build
.PHONY : caffe_cu/fast

#=============================================================================
# Target rules for targets named proto

# Build rule for target.
proto: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 proto
.PHONY : proto

# fast build rule for target.
proto/fast:
	$(MAKE) -f src/caffe/proto/CMakeFiles/proto.dir/build.make src/caffe/proto/CMakeFiles/proto.dir/build
.PHONY : proto/fast

#=============================================================================
# Target rules for targets named main_obj

# Build rule for target.
main_obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 main_obj
.PHONY : main_obj

# fast build rule for target.
main_obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/main_obj.dir/build.make src/caffe/test/CMakeFiles/main_obj.dir/build
.PHONY : main_obj/fast

#=============================================================================
# Target rules for targets named runtest

# Build rule for target.
runtest: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 runtest
.PHONY : runtest

# fast build rule for target.
runtest/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/runtest.dir/build.make src/caffe/test/CMakeFiles/runtest.dir/build
.PHONY : runtest/fast

#=============================================================================
# Target rules for targets named test.testbin

# Build rule for target.
test.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test.testbin
.PHONY : test.testbin

# fast build rule for target.
test.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test.testbin.dir/build.make src/caffe/test/CMakeFiles/test.testbin.dir/build
.PHONY : test.testbin/fast

#=============================================================================
# Target rules for targets named test_accuracy_layer.testbin

# Build rule for target.
test_accuracy_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_accuracy_layer.testbin
.PHONY : test_accuracy_layer.testbin

# fast build rule for target.
test_accuracy_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_accuracy_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_accuracy_layer.testbin.dir/build
.PHONY : test_accuracy_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_accuracy_layer.testbin.obj

# Build rule for target.
test_accuracy_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_accuracy_layer.testbin.obj
.PHONY : test_accuracy_layer.testbin.obj

# fast build rule for target.
test_accuracy_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_accuracy_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_accuracy_layer.testbin.obj.dir/build
.PHONY : test_accuracy_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_argmax_layer.testbin

# Build rule for target.
test_argmax_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_argmax_layer.testbin
.PHONY : test_argmax_layer.testbin

# fast build rule for target.
test_argmax_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_argmax_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_argmax_layer.testbin.dir/build
.PHONY : test_argmax_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_argmax_layer.testbin.obj

# Build rule for target.
test_argmax_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_argmax_layer.testbin.obj
.PHONY : test_argmax_layer.testbin.obj

# fast build rule for target.
test_argmax_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_argmax_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_argmax_layer.testbin.obj.dir/build
.PHONY : test_argmax_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_benchmark.testbin

# Build rule for target.
test_benchmark.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_benchmark.testbin
.PHONY : test_benchmark.testbin

# fast build rule for target.
test_benchmark.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_benchmark.testbin.dir/build.make src/caffe/test/CMakeFiles/test_benchmark.testbin.dir/build
.PHONY : test_benchmark.testbin/fast

#=============================================================================
# Target rules for targets named test_benchmark.testbin.obj

# Build rule for target.
test_benchmark.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_benchmark.testbin.obj
.PHONY : test_benchmark.testbin.obj

# fast build rule for target.
test_benchmark.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_benchmark.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_benchmark.testbin.obj.dir/build
.PHONY : test_benchmark.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_blob.testbin

# Build rule for target.
test_blob.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_blob.testbin
.PHONY : test_blob.testbin

# fast build rule for target.
test_blob.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_blob.testbin.dir/build.make src/caffe/test/CMakeFiles/test_blob.testbin.dir/build
.PHONY : test_blob.testbin/fast

#=============================================================================
# Target rules for targets named test_blob.testbin.obj

# Build rule for target.
test_blob.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_blob.testbin.obj
.PHONY : test_blob.testbin.obj

# fast build rule for target.
test_blob.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_blob.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_blob.testbin.obj.dir/build
.PHONY : test_blob.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_common.testbin

# Build rule for target.
test_common.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_common.testbin
.PHONY : test_common.testbin

# fast build rule for target.
test_common.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_common.testbin.dir/build.make src/caffe/test/CMakeFiles/test_common.testbin.dir/build
.PHONY : test_common.testbin/fast

#=============================================================================
# Target rules for targets named test_common.testbin.obj

# Build rule for target.
test_common.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_common.testbin.obj
.PHONY : test_common.testbin.obj

# fast build rule for target.
test_common.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_common.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_common.testbin.obj.dir/build
.PHONY : test_common.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_concat_layer.testbin

# Build rule for target.
test_concat_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_concat_layer.testbin
.PHONY : test_concat_layer.testbin

# fast build rule for target.
test_concat_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_concat_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_concat_layer.testbin.dir/build
.PHONY : test_concat_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_concat_layer.testbin.obj

# Build rule for target.
test_concat_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_concat_layer.testbin.obj
.PHONY : test_concat_layer.testbin.obj

# fast build rule for target.
test_concat_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_concat_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_concat_layer.testbin.obj.dir/build
.PHONY : test_concat_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_contrastive_loss_layer.testbin

# Build rule for target.
test_contrastive_loss_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_contrastive_loss_layer.testbin
.PHONY : test_contrastive_loss_layer.testbin

# fast build rule for target.
test_contrastive_loss_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_contrastive_loss_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_contrastive_loss_layer.testbin.dir/build
.PHONY : test_contrastive_loss_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_contrastive_loss_layer.testbin.obj

# Build rule for target.
test_contrastive_loss_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_contrastive_loss_layer.testbin.obj
.PHONY : test_contrastive_loss_layer.testbin.obj

# fast build rule for target.
test_contrastive_loss_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_contrastive_loss_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_contrastive_loss_layer.testbin.obj.dir/build
.PHONY : test_contrastive_loss_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_convolution_layer.testbin

# Build rule for target.
test_convolution_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_convolution_layer.testbin
.PHONY : test_convolution_layer.testbin

# fast build rule for target.
test_convolution_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_convolution_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_convolution_layer.testbin.dir/build
.PHONY : test_convolution_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_convolution_layer.testbin.obj

# Build rule for target.
test_convolution_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_convolution_layer.testbin.obj
.PHONY : test_convolution_layer.testbin.obj

# fast build rule for target.
test_convolution_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_convolution_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_convolution_layer.testbin.obj.dir/build
.PHONY : test_convolution_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_data_layer.testbin

# Build rule for target.
test_data_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_data_layer.testbin
.PHONY : test_data_layer.testbin

# fast build rule for target.
test_data_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_data_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_data_layer.testbin.dir/build
.PHONY : test_data_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_data_layer.testbin.obj

# Build rule for target.
test_data_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_data_layer.testbin.obj
.PHONY : test_data_layer.testbin.obj

# fast build rule for target.
test_data_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_data_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_data_layer.testbin.obj.dir/build
.PHONY : test_data_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_dummy_data_layer.testbin

# Build rule for target.
test_dummy_data_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_dummy_data_layer.testbin
.PHONY : test_dummy_data_layer.testbin

# fast build rule for target.
test_dummy_data_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_dummy_data_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_dummy_data_layer.testbin.dir/build
.PHONY : test_dummy_data_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_dummy_data_layer.testbin.obj

# Build rule for target.
test_dummy_data_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_dummy_data_layer.testbin.obj
.PHONY : test_dummy_data_layer.testbin.obj

# fast build rule for target.
test_dummy_data_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_dummy_data_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_dummy_data_layer.testbin.obj.dir/build
.PHONY : test_dummy_data_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_eltwise_layer.testbin

# Build rule for target.
test_eltwise_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_eltwise_layer.testbin
.PHONY : test_eltwise_layer.testbin

# fast build rule for target.
test_eltwise_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_eltwise_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_eltwise_layer.testbin.dir/build
.PHONY : test_eltwise_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_eltwise_layer.testbin.obj

# Build rule for target.
test_eltwise_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_eltwise_layer.testbin.obj
.PHONY : test_eltwise_layer.testbin.obj

# fast build rule for target.
test_eltwise_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_eltwise_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_eltwise_layer.testbin.obj.dir/build
.PHONY : test_eltwise_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_euclidean_loss_layer.testbin

# Build rule for target.
test_euclidean_loss_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_euclidean_loss_layer.testbin
.PHONY : test_euclidean_loss_layer.testbin

# fast build rule for target.
test_euclidean_loss_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_euclidean_loss_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_euclidean_loss_layer.testbin.dir/build
.PHONY : test_euclidean_loss_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_euclidean_loss_layer.testbin.obj

# Build rule for target.
test_euclidean_loss_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_euclidean_loss_layer.testbin.obj
.PHONY : test_euclidean_loss_layer.testbin.obj

# fast build rule for target.
test_euclidean_loss_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_euclidean_loss_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_euclidean_loss_layer.testbin.obj.dir/build
.PHONY : test_euclidean_loss_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_filler.testbin

# Build rule for target.
test_filler.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_filler.testbin
.PHONY : test_filler.testbin

# fast build rule for target.
test_filler.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_filler.testbin.dir/build.make src/caffe/test/CMakeFiles/test_filler.testbin.dir/build
.PHONY : test_filler.testbin/fast

#=============================================================================
# Target rules for targets named test_filler.testbin.obj

# Build rule for target.
test_filler.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_filler.testbin.obj
.PHONY : test_filler.testbin.obj

# fast build rule for target.
test_filler.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_filler.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_filler.testbin.obj.dir/build
.PHONY : test_filler.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_flatten_layer.testbin

# Build rule for target.
test_flatten_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_flatten_layer.testbin
.PHONY : test_flatten_layer.testbin

# fast build rule for target.
test_flatten_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_flatten_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_flatten_layer.testbin.dir/build
.PHONY : test_flatten_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_flatten_layer.testbin.obj

# Build rule for target.
test_flatten_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_flatten_layer.testbin.obj
.PHONY : test_flatten_layer.testbin.obj

# fast build rule for target.
test_flatten_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_flatten_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_flatten_layer.testbin.obj.dir/build
.PHONY : test_flatten_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_gradient_based_solver.testbin

# Build rule for target.
test_gradient_based_solver.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_gradient_based_solver.testbin
.PHONY : test_gradient_based_solver.testbin

# fast build rule for target.
test_gradient_based_solver.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_gradient_based_solver.testbin.dir/build.make src/caffe/test/CMakeFiles/test_gradient_based_solver.testbin.dir/build
.PHONY : test_gradient_based_solver.testbin/fast

#=============================================================================
# Target rules for targets named test_gradient_based_solver.testbin.obj

# Build rule for target.
test_gradient_based_solver.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_gradient_based_solver.testbin.obj
.PHONY : test_gradient_based_solver.testbin.obj

# fast build rule for target.
test_gradient_based_solver.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_gradient_based_solver.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_gradient_based_solver.testbin.obj.dir/build
.PHONY : test_gradient_based_solver.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_hdf5_output_layer.testbin

# Build rule for target.
test_hdf5_output_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_hdf5_output_layer.testbin
.PHONY : test_hdf5_output_layer.testbin

# fast build rule for target.
test_hdf5_output_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_hdf5_output_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_hdf5_output_layer.testbin.dir/build
.PHONY : test_hdf5_output_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_hdf5_output_layer.testbin.obj

# Build rule for target.
test_hdf5_output_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_hdf5_output_layer.testbin.obj
.PHONY : test_hdf5_output_layer.testbin.obj

# fast build rule for target.
test_hdf5_output_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_hdf5_output_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_hdf5_output_layer.testbin.obj.dir/build
.PHONY : test_hdf5_output_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_hdf5data_layer.testbin

# Build rule for target.
test_hdf5data_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_hdf5data_layer.testbin
.PHONY : test_hdf5data_layer.testbin

# fast build rule for target.
test_hdf5data_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_hdf5data_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_hdf5data_layer.testbin.dir/build
.PHONY : test_hdf5data_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_hdf5data_layer.testbin.obj

# Build rule for target.
test_hdf5data_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_hdf5data_layer.testbin.obj
.PHONY : test_hdf5data_layer.testbin.obj

# fast build rule for target.
test_hdf5data_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_hdf5data_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_hdf5data_layer.testbin.obj.dir/build
.PHONY : test_hdf5data_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_hinge_loss_layer.testbin

# Build rule for target.
test_hinge_loss_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_hinge_loss_layer.testbin
.PHONY : test_hinge_loss_layer.testbin

# fast build rule for target.
test_hinge_loss_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_hinge_loss_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_hinge_loss_layer.testbin.dir/build
.PHONY : test_hinge_loss_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_hinge_loss_layer.testbin.obj

# Build rule for target.
test_hinge_loss_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_hinge_loss_layer.testbin.obj
.PHONY : test_hinge_loss_layer.testbin.obj

# fast build rule for target.
test_hinge_loss_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_hinge_loss_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_hinge_loss_layer.testbin.obj.dir/build
.PHONY : test_hinge_loss_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_im2col_kernel.testbin

# Build rule for target.
test_im2col_kernel.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_im2col_kernel.testbin
.PHONY : test_im2col_kernel.testbin

# fast build rule for target.
test_im2col_kernel.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_im2col_kernel.testbin.dir/build.make src/caffe/test/CMakeFiles/test_im2col_kernel.testbin.dir/build
.PHONY : test_im2col_kernel.testbin/fast

#=============================================================================
# Target rules for targets named test_im2col_kernel.testbin.lib

# Build rule for target.
test_im2col_kernel.testbin.lib: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_im2col_kernel.testbin.lib
.PHONY : test_im2col_kernel.testbin.lib

# fast build rule for target.
test_im2col_kernel.testbin.lib/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_im2col_kernel.testbin.lib.dir/build.make src/caffe/test/CMakeFiles/test_im2col_kernel.testbin.lib.dir/build
.PHONY : test_im2col_kernel.testbin.lib/fast

#=============================================================================
# Target rules for targets named test_im2col_layer.testbin

# Build rule for target.
test_im2col_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_im2col_layer.testbin
.PHONY : test_im2col_layer.testbin

# fast build rule for target.
test_im2col_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_im2col_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_im2col_layer.testbin.dir/build
.PHONY : test_im2col_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_im2col_layer.testbin.obj

# Build rule for target.
test_im2col_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_im2col_layer.testbin.obj
.PHONY : test_im2col_layer.testbin.obj

# fast build rule for target.
test_im2col_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_im2col_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_im2col_layer.testbin.obj.dir/build
.PHONY : test_im2col_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_image_data_layer.testbin

# Build rule for target.
test_image_data_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_image_data_layer.testbin
.PHONY : test_image_data_layer.testbin

# fast build rule for target.
test_image_data_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_image_data_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_image_data_layer.testbin.dir/build
.PHONY : test_image_data_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_image_data_layer.testbin.obj

# Build rule for target.
test_image_data_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_image_data_layer.testbin.obj
.PHONY : test_image_data_layer.testbin.obj

# fast build rule for target.
test_image_data_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_image_data_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_image_data_layer.testbin.obj.dir/build
.PHONY : test_image_data_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_infogain_loss_layer.testbin

# Build rule for target.
test_infogain_loss_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_infogain_loss_layer.testbin
.PHONY : test_infogain_loss_layer.testbin

# fast build rule for target.
test_infogain_loss_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_infogain_loss_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_infogain_loss_layer.testbin.dir/build
.PHONY : test_infogain_loss_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_infogain_loss_layer.testbin.obj

# Build rule for target.
test_infogain_loss_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_infogain_loss_layer.testbin.obj
.PHONY : test_infogain_loss_layer.testbin.obj

# fast build rule for target.
test_infogain_loss_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_infogain_loss_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_infogain_loss_layer.testbin.obj.dir/build
.PHONY : test_infogain_loss_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_inner_product_layer.testbin

# Build rule for target.
test_inner_product_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_inner_product_layer.testbin
.PHONY : test_inner_product_layer.testbin

# fast build rule for target.
test_inner_product_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_inner_product_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_inner_product_layer.testbin.dir/build
.PHONY : test_inner_product_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_inner_product_layer.testbin.obj

# Build rule for target.
test_inner_product_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_inner_product_layer.testbin.obj
.PHONY : test_inner_product_layer.testbin.obj

# fast build rule for target.
test_inner_product_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_inner_product_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_inner_product_layer.testbin.obj.dir/build
.PHONY : test_inner_product_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_internal_thread.testbin

# Build rule for target.
test_internal_thread.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_internal_thread.testbin
.PHONY : test_internal_thread.testbin

# fast build rule for target.
test_internal_thread.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_internal_thread.testbin.dir/build.make src/caffe/test/CMakeFiles/test_internal_thread.testbin.dir/build
.PHONY : test_internal_thread.testbin/fast

#=============================================================================
# Target rules for targets named test_internal_thread.testbin.obj

# Build rule for target.
test_internal_thread.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_internal_thread.testbin.obj
.PHONY : test_internal_thread.testbin.obj

# fast build rule for target.
test_internal_thread.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_internal_thread.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_internal_thread.testbin.obj.dir/build
.PHONY : test_internal_thread.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_lrn_layer.testbin

# Build rule for target.
test_lrn_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_lrn_layer.testbin
.PHONY : test_lrn_layer.testbin

# fast build rule for target.
test_lrn_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_lrn_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_lrn_layer.testbin.dir/build
.PHONY : test_lrn_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_lrn_layer.testbin.obj

# Build rule for target.
test_lrn_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_lrn_layer.testbin.obj
.PHONY : test_lrn_layer.testbin.obj

# fast build rule for target.
test_lrn_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_lrn_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_lrn_layer.testbin.obj.dir/build
.PHONY : test_lrn_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_math_functions.testbin

# Build rule for target.
test_math_functions.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_math_functions.testbin
.PHONY : test_math_functions.testbin

# fast build rule for target.
test_math_functions.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_math_functions.testbin.dir/build.make src/caffe/test/CMakeFiles/test_math_functions.testbin.dir/build
.PHONY : test_math_functions.testbin/fast

#=============================================================================
# Target rules for targets named test_math_functions.testbin.obj

# Build rule for target.
test_math_functions.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_math_functions.testbin.obj
.PHONY : test_math_functions.testbin.obj

# fast build rule for target.
test_math_functions.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_math_functions.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_math_functions.testbin.obj.dir/build
.PHONY : test_math_functions.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_maxpool_dropout_layers.testbin

# Build rule for target.
test_maxpool_dropout_layers.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_maxpool_dropout_layers.testbin
.PHONY : test_maxpool_dropout_layers.testbin

# fast build rule for target.
test_maxpool_dropout_layers.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_maxpool_dropout_layers.testbin.dir/build.make src/caffe/test/CMakeFiles/test_maxpool_dropout_layers.testbin.dir/build
.PHONY : test_maxpool_dropout_layers.testbin/fast

#=============================================================================
# Target rules for targets named test_maxpool_dropout_layers.testbin.obj

# Build rule for target.
test_maxpool_dropout_layers.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_maxpool_dropout_layers.testbin.obj
.PHONY : test_maxpool_dropout_layers.testbin.obj

# fast build rule for target.
test_maxpool_dropout_layers.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_maxpool_dropout_layers.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_maxpool_dropout_layers.testbin.obj.dir/build
.PHONY : test_maxpool_dropout_layers.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_memory_data_layer.testbin

# Build rule for target.
test_memory_data_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_memory_data_layer.testbin
.PHONY : test_memory_data_layer.testbin

# fast build rule for target.
test_memory_data_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_memory_data_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_memory_data_layer.testbin.dir/build
.PHONY : test_memory_data_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_memory_data_layer.testbin.obj

# Build rule for target.
test_memory_data_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_memory_data_layer.testbin.obj
.PHONY : test_memory_data_layer.testbin.obj

# fast build rule for target.
test_memory_data_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_memory_data_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_memory_data_layer.testbin.obj.dir/build
.PHONY : test_memory_data_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_multinomial_logistic_loss_layer.testbin

# Build rule for target.
test_multinomial_logistic_loss_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_multinomial_logistic_loss_layer.testbin
.PHONY : test_multinomial_logistic_loss_layer.testbin

# fast build rule for target.
test_multinomial_logistic_loss_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_multinomial_logistic_loss_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_multinomial_logistic_loss_layer.testbin.dir/build
.PHONY : test_multinomial_logistic_loss_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_multinomial_logistic_loss_layer.testbin.obj

# Build rule for target.
test_multinomial_logistic_loss_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_multinomial_logistic_loss_layer.testbin.obj
.PHONY : test_multinomial_logistic_loss_layer.testbin.obj

# fast build rule for target.
test_multinomial_logistic_loss_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_multinomial_logistic_loss_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_multinomial_logistic_loss_layer.testbin.obj.dir/build
.PHONY : test_multinomial_logistic_loss_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_mvn_layer.testbin

# Build rule for target.
test_mvn_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_mvn_layer.testbin
.PHONY : test_mvn_layer.testbin

# fast build rule for target.
test_mvn_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_mvn_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_mvn_layer.testbin.dir/build
.PHONY : test_mvn_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_mvn_layer.testbin.obj

# Build rule for target.
test_mvn_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_mvn_layer.testbin.obj
.PHONY : test_mvn_layer.testbin.obj

# fast build rule for target.
test_mvn_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_mvn_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_mvn_layer.testbin.obj.dir/build
.PHONY : test_mvn_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_net.testbin

# Build rule for target.
test_net.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_net.testbin
.PHONY : test_net.testbin

# fast build rule for target.
test_net.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_net.testbin.dir/build.make src/caffe/test/CMakeFiles/test_net.testbin.dir/build
.PHONY : test_net.testbin/fast

#=============================================================================
# Target rules for targets named test_net.testbin.obj

# Build rule for target.
test_net.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_net.testbin.obj
.PHONY : test_net.testbin.obj

# fast build rule for target.
test_net.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_net.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_net.testbin.obj.dir/build
.PHONY : test_net.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_neuron_layer.testbin

# Build rule for target.
test_neuron_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_neuron_layer.testbin
.PHONY : test_neuron_layer.testbin

# fast build rule for target.
test_neuron_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_neuron_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_neuron_layer.testbin.dir/build
.PHONY : test_neuron_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_neuron_layer.testbin.obj

# Build rule for target.
test_neuron_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_neuron_layer.testbin.obj
.PHONY : test_neuron_layer.testbin.obj

# fast build rule for target.
test_neuron_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_neuron_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_neuron_layer.testbin.obj.dir/build
.PHONY : test_neuron_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_platform.testbin

# Build rule for target.
test_platform.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_platform.testbin
.PHONY : test_platform.testbin

# fast build rule for target.
test_platform.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_platform.testbin.dir/build.make src/caffe/test/CMakeFiles/test_platform.testbin.dir/build
.PHONY : test_platform.testbin/fast

#=============================================================================
# Target rules for targets named test_platform.testbin.obj

# Build rule for target.
test_platform.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_platform.testbin.obj
.PHONY : test_platform.testbin.obj

# fast build rule for target.
test_platform.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_platform.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_platform.testbin.obj.dir/build
.PHONY : test_platform.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_pooling_layer.testbin

# Build rule for target.
test_pooling_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_pooling_layer.testbin
.PHONY : test_pooling_layer.testbin

# fast build rule for target.
test_pooling_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_pooling_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_pooling_layer.testbin.dir/build
.PHONY : test_pooling_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_pooling_layer.testbin.obj

# Build rule for target.
test_pooling_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_pooling_layer.testbin.obj
.PHONY : test_pooling_layer.testbin.obj

# fast build rule for target.
test_pooling_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_pooling_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_pooling_layer.testbin.obj.dir/build
.PHONY : test_pooling_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_power_layer.testbin

# Build rule for target.
test_power_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_power_layer.testbin
.PHONY : test_power_layer.testbin

# fast build rule for target.
test_power_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_power_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_power_layer.testbin.dir/build
.PHONY : test_power_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_power_layer.testbin.obj

# Build rule for target.
test_power_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_power_layer.testbin.obj
.PHONY : test_power_layer.testbin.obj

# fast build rule for target.
test_power_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_power_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_power_layer.testbin.obj.dir/build
.PHONY : test_power_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_protobuf.testbin

# Build rule for target.
test_protobuf.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_protobuf.testbin
.PHONY : test_protobuf.testbin

# fast build rule for target.
test_protobuf.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_protobuf.testbin.dir/build.make src/caffe/test/CMakeFiles/test_protobuf.testbin.dir/build
.PHONY : test_protobuf.testbin/fast

#=============================================================================
# Target rules for targets named test_protobuf.testbin.obj

# Build rule for target.
test_protobuf.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_protobuf.testbin.obj
.PHONY : test_protobuf.testbin.obj

# fast build rule for target.
test_protobuf.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_protobuf.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_protobuf.testbin.obj.dir/build
.PHONY : test_protobuf.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_random_number_generator.testbin

# Build rule for target.
test_random_number_generator.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_random_number_generator.testbin
.PHONY : test_random_number_generator.testbin

# fast build rule for target.
test_random_number_generator.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_random_number_generator.testbin.dir/build.make src/caffe/test/CMakeFiles/test_random_number_generator.testbin.dir/build
.PHONY : test_random_number_generator.testbin/fast

#=============================================================================
# Target rules for targets named test_random_number_generator.testbin.obj

# Build rule for target.
test_random_number_generator.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_random_number_generator.testbin.obj
.PHONY : test_random_number_generator.testbin.obj

# fast build rule for target.
test_random_number_generator.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_random_number_generator.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_random_number_generator.testbin.obj.dir/build
.PHONY : test_random_number_generator.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_sigmoid_cross_entropy_loss_layer.testbin

# Build rule for target.
test_sigmoid_cross_entropy_loss_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_sigmoid_cross_entropy_loss_layer.testbin
.PHONY : test_sigmoid_cross_entropy_loss_layer.testbin

# fast build rule for target.
test_sigmoid_cross_entropy_loss_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_sigmoid_cross_entropy_loss_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_sigmoid_cross_entropy_loss_layer.testbin.dir/build
.PHONY : test_sigmoid_cross_entropy_loss_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_sigmoid_cross_entropy_loss_layer.testbin.obj

# Build rule for target.
test_sigmoid_cross_entropy_loss_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_sigmoid_cross_entropy_loss_layer.testbin.obj
.PHONY : test_sigmoid_cross_entropy_loss_layer.testbin.obj

# fast build rule for target.
test_sigmoid_cross_entropy_loss_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_sigmoid_cross_entropy_loss_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_sigmoid_cross_entropy_loss_layer.testbin.obj.dir/build
.PHONY : test_sigmoid_cross_entropy_loss_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_slice_layer.testbin

# Build rule for target.
test_slice_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_slice_layer.testbin
.PHONY : test_slice_layer.testbin

# fast build rule for target.
test_slice_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_slice_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_slice_layer.testbin.dir/build
.PHONY : test_slice_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_slice_layer.testbin.obj

# Build rule for target.
test_slice_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_slice_layer.testbin.obj
.PHONY : test_slice_layer.testbin.obj

# fast build rule for target.
test_slice_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_slice_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_slice_layer.testbin.obj.dir/build
.PHONY : test_slice_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_softmax_layer.testbin

# Build rule for target.
test_softmax_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_softmax_layer.testbin
.PHONY : test_softmax_layer.testbin

# fast build rule for target.
test_softmax_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_softmax_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_softmax_layer.testbin.dir/build
.PHONY : test_softmax_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_softmax_layer.testbin.obj

# Build rule for target.
test_softmax_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_softmax_layer.testbin.obj
.PHONY : test_softmax_layer.testbin.obj

# fast build rule for target.
test_softmax_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_softmax_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_softmax_layer.testbin.obj.dir/build
.PHONY : test_softmax_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_softmax_with_loss_layer.testbin

# Build rule for target.
test_softmax_with_loss_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_softmax_with_loss_layer.testbin
.PHONY : test_softmax_with_loss_layer.testbin

# fast build rule for target.
test_softmax_with_loss_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_softmax_with_loss_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_softmax_with_loss_layer.testbin.dir/build
.PHONY : test_softmax_with_loss_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_softmax_with_loss_layer.testbin.obj

# Build rule for target.
test_softmax_with_loss_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_softmax_with_loss_layer.testbin.obj
.PHONY : test_softmax_with_loss_layer.testbin.obj

# fast build rule for target.
test_softmax_with_loss_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_softmax_with_loss_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_softmax_with_loss_layer.testbin.obj.dir/build
.PHONY : test_softmax_with_loss_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_solver.testbin

# Build rule for target.
test_solver.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_solver.testbin
.PHONY : test_solver.testbin

# fast build rule for target.
test_solver.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_solver.testbin.dir/build.make src/caffe/test/CMakeFiles/test_solver.testbin.dir/build
.PHONY : test_solver.testbin/fast

#=============================================================================
# Target rules for targets named test_solver.testbin.obj

# Build rule for target.
test_solver.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_solver.testbin.obj
.PHONY : test_solver.testbin.obj

# fast build rule for target.
test_solver.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_solver.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_solver.testbin.obj.dir/build
.PHONY : test_solver.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_split_layer.testbin

# Build rule for target.
test_split_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_split_layer.testbin
.PHONY : test_split_layer.testbin

# fast build rule for target.
test_split_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_split_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_split_layer.testbin.dir/build
.PHONY : test_split_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_split_layer.testbin.obj

# Build rule for target.
test_split_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_split_layer.testbin.obj
.PHONY : test_split_layer.testbin.obj

# fast build rule for target.
test_split_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_split_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_split_layer.testbin.obj.dir/build
.PHONY : test_split_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_stochastic_pooling.testbin

# Build rule for target.
test_stochastic_pooling.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_stochastic_pooling.testbin
.PHONY : test_stochastic_pooling.testbin

# fast build rule for target.
test_stochastic_pooling.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_stochastic_pooling.testbin.dir/build.make src/caffe/test/CMakeFiles/test_stochastic_pooling.testbin.dir/build
.PHONY : test_stochastic_pooling.testbin/fast

#=============================================================================
# Target rules for targets named test_stochastic_pooling.testbin.obj

# Build rule for target.
test_stochastic_pooling.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_stochastic_pooling.testbin.obj
.PHONY : test_stochastic_pooling.testbin.obj

# fast build rule for target.
test_stochastic_pooling.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_stochastic_pooling.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_stochastic_pooling.testbin.obj.dir/build
.PHONY : test_stochastic_pooling.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_syncedmem.testbin

# Build rule for target.
test_syncedmem.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_syncedmem.testbin
.PHONY : test_syncedmem.testbin

# fast build rule for target.
test_syncedmem.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_syncedmem.testbin.dir/build.make src/caffe/test/CMakeFiles/test_syncedmem.testbin.dir/build
.PHONY : test_syncedmem.testbin/fast

#=============================================================================
# Target rules for targets named test_syncedmem.testbin.obj

# Build rule for target.
test_syncedmem.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_syncedmem.testbin.obj
.PHONY : test_syncedmem.testbin.obj

# fast build rule for target.
test_syncedmem.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_syncedmem.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_syncedmem.testbin.obj.dir/build
.PHONY : test_syncedmem.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_threshold_layer.testbin

# Build rule for target.
test_threshold_layer.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_threshold_layer.testbin
.PHONY : test_threshold_layer.testbin

# fast build rule for target.
test_threshold_layer.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_threshold_layer.testbin.dir/build.make src/caffe/test/CMakeFiles/test_threshold_layer.testbin.dir/build
.PHONY : test_threshold_layer.testbin/fast

#=============================================================================
# Target rules for targets named test_threshold_layer.testbin.obj

# Build rule for target.
test_threshold_layer.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_threshold_layer.testbin.obj
.PHONY : test_threshold_layer.testbin.obj

# fast build rule for target.
test_threshold_layer.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_threshold_layer.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_threshold_layer.testbin.obj.dir/build
.PHONY : test_threshold_layer.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_upgrade_proto.testbin

# Build rule for target.
test_upgrade_proto.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_upgrade_proto.testbin
.PHONY : test_upgrade_proto.testbin

# fast build rule for target.
test_upgrade_proto.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_upgrade_proto.testbin.dir/build.make src/caffe/test/CMakeFiles/test_upgrade_proto.testbin.dir/build
.PHONY : test_upgrade_proto.testbin/fast

#=============================================================================
# Target rules for targets named test_upgrade_proto.testbin.obj

# Build rule for target.
test_upgrade_proto.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_upgrade_proto.testbin.obj
.PHONY : test_upgrade_proto.testbin.obj

# fast build rule for target.
test_upgrade_proto.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_upgrade_proto.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_upgrade_proto.testbin.obj.dir/build
.PHONY : test_upgrade_proto.testbin.obj/fast

#=============================================================================
# Target rules for targets named test_util_blas.testbin

# Build rule for target.
test_util_blas.testbin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_util_blas.testbin
.PHONY : test_util_blas.testbin

# fast build rule for target.
test_util_blas.testbin/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_util_blas.testbin.dir/build.make src/caffe/test/CMakeFiles/test_util_blas.testbin.dir/build
.PHONY : test_util_blas.testbin/fast

#=============================================================================
# Target rules for targets named test_util_blas.testbin.obj

# Build rule for target.
test_util_blas.testbin.obj: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_util_blas.testbin.obj
.PHONY : test_util_blas.testbin.obj

# fast build rule for target.
test_util_blas.testbin.obj/fast:
	$(MAKE) -f src/caffe/test/CMakeFiles/test_util_blas.testbin.obj.dir/build.make src/caffe/test/CMakeFiles/test_util_blas.testbin.obj.dir/build
.PHONY : test_util_blas.testbin.obj/fast

#=============================================================================
# Target rules for targets named caffe.bin

# Build rule for target.
caffe.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 caffe.bin
.PHONY : caffe.bin

# fast build rule for target.
caffe.bin/fast:
	$(MAKE) -f tools/CMakeFiles/caffe.bin.dir/build.make tools/CMakeFiles/caffe.bin.dir/build
.PHONY : caffe.bin/fast

#=============================================================================
# Target rules for targets named compute_image_mean.bin

# Build rule for target.
compute_image_mean.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 compute_image_mean.bin
.PHONY : compute_image_mean.bin

# fast build rule for target.
compute_image_mean.bin/fast:
	$(MAKE) -f tools/CMakeFiles/compute_image_mean.bin.dir/build.make tools/CMakeFiles/compute_image_mean.bin.dir/build
.PHONY : compute_image_mean.bin/fast

#=============================================================================
# Target rules for targets named convert_imageset.bin

# Build rule for target.
convert_imageset.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 convert_imageset.bin
.PHONY : convert_imageset.bin

# fast build rule for target.
convert_imageset.bin/fast:
	$(MAKE) -f tools/CMakeFiles/convert_imageset.bin.dir/build.make tools/CMakeFiles/convert_imageset.bin.dir/build
.PHONY : convert_imageset.bin/fast

#=============================================================================
# Target rules for targets named device_query.bin

# Build rule for target.
device_query.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 device_query.bin
.PHONY : device_query.bin

# fast build rule for target.
device_query.bin/fast:
	$(MAKE) -f tools/CMakeFiles/device_query.bin.dir/build.make tools/CMakeFiles/device_query.bin.dir/build
.PHONY : device_query.bin/fast

#=============================================================================
# Target rules for targets named dump_network.bin

# Build rule for target.
dump_network.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 dump_network.bin
.PHONY : dump_network.bin

# fast build rule for target.
dump_network.bin/fast:
	$(MAKE) -f tools/CMakeFiles/dump_network.bin.dir/build.make tools/CMakeFiles/dump_network.bin.dir/build
.PHONY : dump_network.bin/fast

#=============================================================================
# Target rules for targets named extract_features.bin

# Build rule for target.
extract_features.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 extract_features.bin
.PHONY : extract_features.bin

# fast build rule for target.
extract_features.bin/fast:
	$(MAKE) -f tools/CMakeFiles/extract_features.bin.dir/build.make tools/CMakeFiles/extract_features.bin.dir/build
.PHONY : extract_features.bin/fast

#=============================================================================
# Target rules for targets named finetune_net.bin

# Build rule for target.
finetune_net.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 finetune_net.bin
.PHONY : finetune_net.bin

# fast build rule for target.
finetune_net.bin/fast:
	$(MAKE) -f tools/CMakeFiles/finetune_net.bin.dir/build.make tools/CMakeFiles/finetune_net.bin.dir/build
.PHONY : finetune_net.bin/fast

#=============================================================================
# Target rules for targets named net_speed_benchmark.bin

# Build rule for target.
net_speed_benchmark.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 net_speed_benchmark.bin
.PHONY : net_speed_benchmark.bin

# fast build rule for target.
net_speed_benchmark.bin/fast:
	$(MAKE) -f tools/CMakeFiles/net_speed_benchmark.bin.dir/build.make tools/CMakeFiles/net_speed_benchmark.bin.dir/build
.PHONY : net_speed_benchmark.bin/fast

#=============================================================================
# Target rules for targets named test_net.bin

# Build rule for target.
test_net.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 test_net.bin
.PHONY : test_net.bin

# fast build rule for target.
test_net.bin/fast:
	$(MAKE) -f tools/CMakeFiles/test_net.bin.dir/build.make tools/CMakeFiles/test_net.bin.dir/build
.PHONY : test_net.bin/fast

#=============================================================================
# Target rules for targets named train_net.bin

# Build rule for target.
train_net.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 train_net.bin
.PHONY : train_net.bin

# fast build rule for target.
train_net.bin/fast:
	$(MAKE) -f tools/CMakeFiles/train_net.bin.dir/build.make tools/CMakeFiles/train_net.bin.dir/build
.PHONY : train_net.bin/fast

#=============================================================================
# Target rules for targets named upgrade_net_proto_binary.bin

# Build rule for target.
upgrade_net_proto_binary.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 upgrade_net_proto_binary.bin
.PHONY : upgrade_net_proto_binary.bin

# fast build rule for target.
upgrade_net_proto_binary.bin/fast:
	$(MAKE) -f tools/CMakeFiles/upgrade_net_proto_binary.bin.dir/build.make tools/CMakeFiles/upgrade_net_proto_binary.bin.dir/build
.PHONY : upgrade_net_proto_binary.bin/fast

#=============================================================================
# Target rules for targets named upgrade_net_proto_text.bin

# Build rule for target.
upgrade_net_proto_text.bin: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 upgrade_net_proto_text.bin
.PHONY : upgrade_net_proto_text.bin

# fast build rule for target.
upgrade_net_proto_text.bin/fast:
	$(MAKE) -f tools/CMakeFiles/upgrade_net_proto_text.bin.dir/build.make tools/CMakeFiles/upgrade_net_proto_text.bin.dir/build
.PHONY : upgrade_net_proto_text.bin/fast

#=============================================================================
# Target rules for targets named convert_cifar_data

# Build rule for target.
convert_cifar_data: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 convert_cifar_data
.PHONY : convert_cifar_data

# fast build rule for target.
convert_cifar_data/fast:
	$(MAKE) -f examples/CMakeFiles/convert_cifar_data.dir/build.make examples/CMakeFiles/convert_cifar_data.dir/build
.PHONY : convert_cifar_data/fast

#=============================================================================
# Target rules for targets named convert_mnist_data

# Build rule for target.
convert_mnist_data: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 convert_mnist_data
.PHONY : convert_mnist_data

# fast build rule for target.
convert_mnist_data/fast:
	$(MAKE) -f examples/CMakeFiles/convert_mnist_data.dir/build.make examples/CMakeFiles/convert_mnist_data.dir/build
.PHONY : convert_mnist_data/fast

#=============================================================================
# Target rules for targets named convert_mnist_siamese_data

# Build rule for target.
convert_mnist_siamese_data: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 convert_mnist_siamese_data
.PHONY : convert_mnist_siamese_data

# fast build rule for target.
convert_mnist_siamese_data/fast:
	$(MAKE) -f examples/CMakeFiles/convert_mnist_siamese_data.dir/build.make examples/CMakeFiles/convert_mnist_siamese_data.dir/build
.PHONY : convert_mnist_siamese_data/fast

#=============================================================================
# Target rules for targets named pycaffe

# Build rule for target.
pycaffe: cmake_check_build_system
	$(MAKE) -f CMakeFiles/Makefile2 pycaffe
.PHONY : pycaffe

# fast build rule for target.
pycaffe/fast:
	$(MAKE) -f python/CMakeFiles/pycaffe.dir/build.make python/CMakeFiles/pycaffe.dir/build
.PHONY : pycaffe/fast

# Help Target
help:
	@echo "The following are some of the valid targets for this Makefile:"
	@echo "... all (the default if no target is provided)"
	@echo "... clean"
	@echo "... depend"
	@echo "... edit_cache"
	@echo "... install"
	@echo "... install/local"
	@echo "... install/strip"
	@echo "... lint"
	@echo "... list_install_components"
	@echo "... rebuild_cache"
	@echo "... gtest"
	@echo "... gtest_main"
	@echo "... caffe"
	@echo "... caffe_cu"
	@echo "... proto"
	@echo "... main_obj"
	@echo "... runtest"
	@echo "... test.testbin"
	@echo "... test_accuracy_layer.testbin"
	@echo "... test_accuracy_layer.testbin.obj"
	@echo "... test_argmax_layer.testbin"
	@echo "... test_argmax_layer.testbin.obj"
	@echo "... test_benchmark.testbin"
	@echo "... test_benchmark.testbin.obj"
	@echo "... test_blob.testbin"
	@echo "... test_blob.testbin.obj"
	@echo "... test_common.testbin"
	@echo "... test_common.testbin.obj"
	@echo "... test_concat_layer.testbin"
	@echo "... test_concat_layer.testbin.obj"
	@echo "... test_contrastive_loss_layer.testbin"
	@echo "... test_contrastive_loss_layer.testbin.obj"
	@echo "... test_convolution_layer.testbin"
	@echo "... test_convolution_layer.testbin.obj"
	@echo "... test_data_layer.testbin"
	@echo "... test_data_layer.testbin.obj"
	@echo "... test_dummy_data_layer.testbin"
	@echo "... test_dummy_data_layer.testbin.obj"
	@echo "... test_eltwise_layer.testbin"
	@echo "... test_eltwise_layer.testbin.obj"
	@echo "... test_euclidean_loss_layer.testbin"
	@echo "... test_euclidean_loss_layer.testbin.obj"
	@echo "... test_filler.testbin"
	@echo "... test_filler.testbin.obj"
	@echo "... test_flatten_layer.testbin"
	@echo "... test_flatten_layer.testbin.obj"
	@echo "... test_gradient_based_solver.testbin"
	@echo "... test_gradient_based_solver.testbin.obj"
	@echo "... test_hdf5_output_layer.testbin"
	@echo "... test_hdf5_output_layer.testbin.obj"
	@echo "... test_hdf5data_layer.testbin"
	@echo "... test_hdf5data_layer.testbin.obj"
	@echo "... test_hinge_loss_layer.testbin"
	@echo "... test_hinge_loss_layer.testbin.obj"
	@echo "... test_im2col_kernel.testbin"
	@echo "... test_im2col_kernel.testbin.lib"
	@echo "... test_im2col_layer.testbin"
	@echo "... test_im2col_layer.testbin.obj"
	@echo "... test_image_data_layer.testbin"
	@echo "... test_image_data_layer.testbin.obj"
	@echo "... test_infogain_loss_layer.testbin"
	@echo "... test_infogain_loss_layer.testbin.obj"
	@echo "... test_inner_product_layer.testbin"
	@echo "... test_inner_product_layer.testbin.obj"
	@echo "... test_internal_thread.testbin"
	@echo "... test_internal_thread.testbin.obj"
	@echo "... test_lrn_layer.testbin"
	@echo "... test_lrn_layer.testbin.obj"
	@echo "... test_math_functions.testbin"
	@echo "... test_math_functions.testbin.obj"
	@echo "... test_maxpool_dropout_layers.testbin"
	@echo "... test_maxpool_dropout_layers.testbin.obj"
	@echo "... test_memory_data_layer.testbin"
	@echo "... test_memory_data_layer.testbin.obj"
	@echo "... test_multinomial_logistic_loss_layer.testbin"
	@echo "... test_multinomial_logistic_loss_layer.testbin.obj"
	@echo "... test_mvn_layer.testbin"
	@echo "... test_mvn_layer.testbin.obj"
	@echo "... test_net.testbin"
	@echo "... test_net.testbin.obj"
	@echo "... test_neuron_layer.testbin"
	@echo "... test_neuron_layer.testbin.obj"
	@echo "... test_platform.testbin"
	@echo "... test_platform.testbin.obj"
	@echo "... test_pooling_layer.testbin"
	@echo "... test_pooling_layer.testbin.obj"
	@echo "... test_power_layer.testbin"
	@echo "... test_power_layer.testbin.obj"
	@echo "... test_protobuf.testbin"
	@echo "... test_protobuf.testbin.obj"
	@echo "... test_random_number_generator.testbin"
	@echo "... test_random_number_generator.testbin.obj"
	@echo "... test_sigmoid_cross_entropy_loss_layer.testbin"
	@echo "... test_sigmoid_cross_entropy_loss_layer.testbin.obj"
	@echo "... test_slice_layer.testbin"
	@echo "... test_slice_layer.testbin.obj"
	@echo "... test_softmax_layer.testbin"
	@echo "... test_softmax_layer.testbin.obj"
	@echo "... test_softmax_with_loss_layer.testbin"
	@echo "... test_softmax_with_loss_layer.testbin.obj"
	@echo "... test_solver.testbin"
	@echo "... test_solver.testbin.obj"
	@echo "... test_split_layer.testbin"
	@echo "... test_split_layer.testbin.obj"
	@echo "... test_stochastic_pooling.testbin"
	@echo "... test_stochastic_pooling.testbin.obj"
	@echo "... test_syncedmem.testbin"
	@echo "... test_syncedmem.testbin.obj"
	@echo "... test_threshold_layer.testbin"
	@echo "... test_threshold_layer.testbin.obj"
	@echo "... test_upgrade_proto.testbin"
	@echo "... test_upgrade_proto.testbin.obj"
	@echo "... test_util_blas.testbin"
	@echo "... test_util_blas.testbin.obj"
	@echo "... caffe.bin"
	@echo "... compute_image_mean.bin"
	@echo "... convert_imageset.bin"
	@echo "... device_query.bin"
	@echo "... dump_network.bin"
	@echo "... extract_features.bin"
	@echo "... finetune_net.bin"
	@echo "... net_speed_benchmark.bin"
	@echo "... test_net.bin"
	@echo "... train_net.bin"
	@echo "... upgrade_net_proto_binary.bin"
	@echo "... upgrade_net_proto_text.bin"
	@echo "... convert_cifar_data"
	@echo "... convert_mnist_data"
	@echo "... convert_mnist_siamese_data"
	@echo "... pycaffe"
.PHONY : help



#=============================================================================
# Special targets to cleanup operation of make.

# Special rule to run CMake to check the build system integrity.
# No rule that depends on this can have commands that come from listfiles
# because they might be regenerated.
cmake_check_build_system:
	$(CMAKE_COMMAND) -H$(CMAKE_SOURCE_DIR) -B$(CMAKE_BINARY_DIR) --check-build-system CMakeFiles/Makefile.cmake 0
.PHONY : cmake_check_build_system

>>>>>>> ''
