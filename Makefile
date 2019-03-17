# A Progressive FULL Depdendency BUILD framework designed for clean code
# and support full view of the dependency tree with make2graph
#
# Copyright 2008, 2009, 2010 Dan Moulding, Alan T. DeKok
# Copyright 2018 Dequan Zhang
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

############################################################################
######                                                              ########
######  Don't edit rules below unless you know what you are doing   ########
######                                                              ########
############################################################################
# Caution: Only edit this if you need to modify Makefile's behavior
#  (fix bugs, add features, etc.) Don't edit this Makefile otherwise!
# Create your own Makefrag and other submakefiles, which will be included by this Makefile.

-include /sources/config.make

MAIN := Makefrag

.RECIPEPREFIX := !
.DEFAULT_GOAL := all

############################################################################
######                                                              ########
######                         MAKEFILE COLORS                      ########
######                                                              ########
############################################################################
COLOR:=$(strip $(shell if [ -t 1 ] ; then echo ON ; else echo OFF ; fi))

COLOR_TERMINAL_NONE         := "\033[0m"
COLOR_TERMINAL_BLACK        := "\033[0;30m"
COLOR_TERMINAL_GRAY         := "\033[1;30m"
COLOR_TERMINAL_BG_GRAY      := "\033[1;100m"
COLOR_TERMINAL_RED          := "\033[0;31m"
COLOR_TERMINAL_BOLD_RED     := "\033[1;31m"
COLOR_TERMINAL_GREEN        := "\033[0;32m"
COLOR_TERMINAL_BOLD_GREEN   := "\033[1;32m"
COLOR_TERMINAL_YELLOW       := "\033[0;33m"
COLOR_TERMINAL_BOLD_YELLOW  := "\033[1;33m"
COLOR_TERMINAL_BLUE         := "\033[0;34m"
COLOR_TERMINAL_LIGTH_BLUE   := "\033[1;34m"
COLOR_TERMINAL_PURPLE       := "\033[0;35m"
COLOR_TERMINAL_BOLD_PURPLE  := "\033[1;35m"
COLOR_TERMINAL_CYAN         := "\033[0;36m"
COLOR_TERMINAL_BOLD_CYAN    := "\033[1;36m"
COLOR_TERMINAL_WHITE        := "\033[1;37m"

COLOR_TEXT_ON = $(COLOR_TERMINAL_$(strip $(1)))$(strip $(2))$(COLOR_TERMINAL_NONE)
COLOR_TEXT_OFF = $(strip $(2))
color_text  = $(call COLOR_TEXT_$(COLOR),$(1),$(2))
$(info $(color_text))
ok    = $(call color_text, GREEN,  ${1})
err   = $(call color_text, RED,    ${1})
warn  = $(call color_text, YELLOW, ${1})
h1    = $(call color_text, CYAN,   ${1})
h2    = $(call color_text, CYAN,   "  ${1}")
ifndef DEBUG
gray  = $(call color_text, GRAY,   "")
endif
ifdef DEBUG
gray  = $(call color_text, GRAY,   ${1})
endif
# Example Usage inside the recipe
# @echo $(call ok, $$(strip $${AR} $${ARFLAGS} $$@)) "\\" $(call h2,"#TARGET") "\n"

############################################################################
######                                                              ########
######                       MAKEFILE FUNCTION DEFINED              ########
######                                                              ########
############################################################################

# Note: Parameterized "functions" in this makefile that are marked with
#       "USE WITH EVAL E.g. $(eval $(call function agruments))"
#       are only useful in conjuction with eval. This is because
#       those functions result in a block of Makefile syntax that must
#       be evaluated after expansion. Since they must be used with eval, most
#       instances of "$" within them need to be escaped with a second "$" to
#       accomodate the double expansion that occurs when eval is invoked.

# ADD_TEST_RULE - Parameterized "function" that adds a new rule and phony
#   target for install the specified target (from its build-generated
#   files).
#
#   USE WITH EVAL E.g. $(eval $(call function agruments))
#
define ADD_TEST_RULE
    test: test_${1}
    .PHONY: test_${1}
    test_${1}:
!       $${${1}_TEST}
endef

# ADD_INSTALL_RULE - Parameterized "function" that adds a new rule and phony
#   target for install the specified target (from its build-generated
#   files).
#
#   USE WITH EVAL E.g. $(eval $(call function agruments))
#
define ADD_INSTALL_RULE
    install: install_${1}
    .PHONY: install_${1}
    install_${1}:
!       $${${1}_INSTALL}
endef

# ADD_CLEAN_RULE - Parameterized "function" that adds a new rule and phony
#   target for cleaning the specified target (removing its build-generated
#   files).
#
#   USE WITH EVAL E.g. $(eval $(call function agruments))
#
define ADD_CLEAN_RULE
    distclean: clean_${1}
    .PHONY: clean_${1}
    clean_${1}:
!       $${${1}_PRIORCLEAN}
!       $$(strip rm -f $(abspath $(call CANONICAL_PATH,${TARGET_DIR}/${1})) $${${1}_OBJS:%.o=%.[doP]})
!       $${${1}_POSTCLEAN}
endef

# ADD_OBJECT_RULE path, src_extention, recipe(compile cmds), recipe(for unit test)
#   Parameterized "function" that adds a pattern rule for
#   building object files from source files with the filename extension
#   specified in the second argument. The first argument must be the name of the
#   base directory where the object files should reside (such that the portion
#   of the path after the base directory will match the path to corresponding
#   source files). The third argument must contain the rules used to compile the
#   source files into object code form.
#
#   USE WITH EVAL E.g. $(eval $(call function agruments))
#
define ADD_OBJECT_RULE
    ${1}/%.o: ${2}
!       ${3}
    ifdef UNITTEST
!       ${4}
    endif
endef

# ADD_TARGET_RULE - Parameterized "function" that adds a new target to the
#   Makefile. The target may be an executable or a library. The two allowable
#   types of targets are distinguished based on the name: library targets must
#   end with the traditional ".a" extension.
#
#   USE WITH EVAL E.g. $(eval $(call function agruments))
#
define ADD_TARGET_RULE
    ifeq "$$(suffix ${1})" ".external"
        # Add a target depdency built by SDK, external makefiles/build system,etc
        $${TARGET_DIR}/${1}: $${${1}_PREREQS}
!            @mkdir -p $$(dir $$@)
!            $${${1}_PRIORMAKE}
!            $${${1}_POSTMAKE}
    else
    ifeq "$$(suffix ${1})" ".a"
        # Add a target for creating a static library.
        $${TARGET_DIR}/${1}: $${${1}_OBJS} $${${1}_PREREQS}
!            @mkdir -p $$(dir $$@)
!            $${${1}_PRIORMAKE}
!            @true $(call h1, $(strip @TARGET_RULE $$@: $$+))
!            @echo -e $(call ok, $$(strip $${AR} $${ARFLAGS} $$@)) $(call gray, $$(strip $${${1}_OBJS}))
!            @$$(strip $${AR} $${ARFLAGS} $$@ $${${1}_OBJS})
!            $${${1}_POSTMAKE}

    else
    ifeq "$$(suffix ${1})" ".so"
        # Add a target for creating a shared library for c only.
        $${TARGET_DIR}/${1}: $${${1}_OBJS} $${${1}_PREREQS}
!            @mkdir -p $$(dir $$@)
!            $${${1}_PRIORMAKE}
!            @true $(call h1, $(strip @TARGET_RULE $$@: $$+))
!            @echo -e $(call ok, $$(strip $${CC} -shared -o $$@)) $(call gray, $$(strip $${LDFLAGS} $${${1}_LDFLAGS} $${${1}_OBJS} $${LDFLAGS} $${${1}_LDFLAGS}))
!            @$$(strip $${CC} -shared -o $$@ $${LDFLAGS} $${${1}_LDFLAGS} $${${1}_OBJS}) $${LDFLAGS} $${${1}_LDFLAGS}
!            $${${1}_POSTMAKE}
    else
        # Add a target for linking an executable. First, attempt to select the
        # appropriate front-end to use for linking. This might not choose the
        # right one (e.g. if linking with a C++ static library, but all other
        # sources are C sources), so the user makefile is allowed to specify a
        # linker to be used for each target.
        ifeq "$$(strip $${${1}_LINKER})" ""
            # No linker was explicitly specified to be used for this target. If
            # there are any C++ sources for this target, use the C++ compiler.
            # For all other targets, default to using the C compiler.
            ifneq "$$(strip $$(filter $${CXX_SRC_EXTS},$${${1}_SOURCES}))" ""
                ${1}_LINKER = $${CXX}
            else
                ${1}_LINKER = $${CC}
            endif
        endif
        # Link all library and objects at the end for a good reason
        # a depdens on b, put b after a, repeat inclusion for circular depdency
        $${TARGET_DIR}/${1}: $${${1}_OBJS} $${${1}_PREREQS}
!            @mkdir -p $$(dir $$@)
!            $${${1}_PRIORMAKE}
!            @true $(call h1, $(strip @TARGET_RULE $$@: $$+))
!            @echo -e $(call ok, $$(strip $${${1}_LINKER} -o $$@ )) $(call gray, $$(strip $${LDFLAGS} $${${1}_LDFLAGS} $${${1}_OBJS} $${LDFLAGS} $${${1}_LDFLAGS}))
!            @$$(strip $${${1}_LINKER} -o $$@ $${LDFLAGS} $${${1}_LDFLAGS} $${${1}_OBJS}) $${LDFLAGS} $${${1}_LDFLAGS}
!            $${${1}_POSTMAKE}
    endif
    endif
    endif
    # type make target easier in command line
    .PHONY: $$(notdir $${TARGET_DIR}/${1})
    $$(notdir $${TARGET_DIR}/${1}):$${TARGET_DIR}/${1}
endef #ADD_TARGET_RULE

# CANONICAL_PATH - Given one or more paths, converts the paths to the canonical
#   form. The canonical form is the path, relative to the project's top-level
#   directory (the directory from which "make" is run),
#   and without any "./" or "../" sequences. For paths that are not  located below the
#   top-level directory, the canonical form is the absolute path (i.e. from
#   the root of the filesystem) also without "./" or "../" sequences.
define CANONICAL_PATH
$(patsubst ${CURDIR}/%,%,$(abspath ${1}))
endef

# BOTH COMPILE_CMDS USE AUTO_GENERATED DEPEDENCY INFORMATION
# From the compiler

# COMPILE_C_CMDS - Commands for compiling C source code.
define COMPILE_C_CMDS
    @mkdir -p $(dir $@)
    @true $(call h1, $(strip @TARGET_RULE $@: $+))
    @echo -e $(call ok, $(strip ${CC} -c $(strip $(abspath $<)))) $(call gray, $(strip -MMD ${CFLAGS} ${SRC_CFLAGS} ${SRC_INCDIRS} ${SRC_DEFS}  -o $@))
    @$(strip ${CC} -c $(strip $(abspath $<))) -MMD ${CFLAGS} ${SRC_CFLAGS} ${SRC_INCDIRS} ${SRC_DEFS}  -o $@
    @cp ${@:%$(suffix $@)=%.d} ${@:%$(suffix $@)=%.P}
    @sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' -e '/^$$/ d' -e 's/$$/ :/' < ${@:%$(suffix $@)=%.d} >> ${@:%$(suffix $@)=%.P}
    @rm -f ${@:%$(suffix $@)=%.d}
endef

# COMPILE_CXX_CMDS - Commands for compiling C++ source code.
define COMPILE_CXX_CMDS
    @mkdir -p $(dir $@)
    @true $(call h1, $(strip @TARGET_RULE $@: $+))
    @echo -e $(call ok, $(strip ${CXX} -c $(strip $(abspath $<))) $(call gray, $(strip -MMD ${CXXFLAGS} ${SRC_CXXFLAGS} ${SRC_INCDIRS} ${SRC_DEFS}  -o $@))
    @$(strip ${CXX} -c -o $@ -MMD ${CXXFLAGS} ${SRC_CXXFLAGS} ${SRC_INCDIRS} ${SRC_DEFS} $(strip $(abspath $<)))
    @cp ${@:%$(suffix $@)=%.d} ${@:%$(suffix $@)=%.P}
    @sed -e 's/#.*//' -e 's/^[^:]*: *//' -e 's/ *\\$$//' -e '/^$$/ d' -e 's/$$/ :/' < ${@:%$(suffix $@)=%.d} >> ${@:%$(suffix $@)=%.P}
    @rm -f ${@:%$(suffix $@)=%.d}
endef

# UNIT_TEST_CMDS - Commands for create/run unit test on the objects
define UNIT_TEST_CMDS
    @$(call h1, "GENERATE/RUNNING UNIT_TEST... ")
    @python generate_unit_function.py $(strip $(abspath $<)) $(strip ${CC} ${CFLAGS} ${SRC_CFLAGS} ${INCDIRS} ${SRC_INCDIRS} ${SRC_DEFS} )
endef

# INCLUDE_SUBMAKEFILE - Parameterized "function" that includes a new
#   "submakefile" fragment into the overall Makefile. It also recursively
#   includes all submakefiles of the specified submakefile fragment.
#
#   USE WITH EVAL E.g. $(eval $(call function agruments))
#
define INCLUDE_SUBMAKEFILE
    # Initialize all variables that can be defined by a makefile fragment, then
    # include the specified makefile fragment.
    TARGET          :=
    TGT_CFLAGS      :=
    TGT_CXXFLAGS    :=
    TGT_DEFS        :=
    TGT_INCDIRS     :=
    TGT_LDFLAGS     :=
    TGT_LINKER      :=
    TGT_PRIORCLEAN  :=
    TGT_POSTCLEAN   :=
    TGT_PRIORMAKE   :=
    TGT_POSTMAKE    :=
    TGT_TEST        :=
    TGT_INSTALL     :=
    TGT_PREREQS     :=

    SOURCES         :=
    SRC_CFLAGS      :=
    SRC_CXXFLAGS    :=
    SRC_DEFS        :=
    SRC_INCDIRS     :=

    SUBMAKEFILES    :=

    # A directory stack is maintained so that the correct paths are used as we
    # recursively include all submakefiles. Get the makefile's directory and
    # push it onto the stack.
    DIR := $(call CANONICAL_PATH,$(dir ${1}))
    DIR_STACK := $$(call PUSH,$${DIR_STACK},$${DIR})

    include ${1}

    # Initialize internal local variables.
    OBJS :=

    # Ensure that valid values are set for BUILD_DIR and TARGET_DIR.
    ifeq "$$(strip $${BUILD_DIR})" ""
        BUILD_DIR := build
    endif
    ifeq "$$(strip $${TARGET_DIR})" ""
        TARGET_DIR := .
    endif

    # Determine which target this makefile's variables apply to. A stack is
    # used to keep track of which target is the "current" target as we
    # recursively include other submakefiles.
    ifneq "$$(strip $${TARGET})" ""
        # This makefile defined a new target. Target variables defined by this
        # makefile apply to this new target. Initialize the target's variables.
        # TODO: error flag if there are more than one target to be defined
        TGT := $$(strip $${TARGET})
        ALL_TGTS += $${TGT}
        $${TGT}_SOURCES    :=
        $${TGT}_DEPS       :=
        $${TGT}_OBJS       :=
        $${TGT}_CFLAGS     := $${TGT_CFLAGS}
        $${TGT}_CXXFLAGS   := $${TGT_CXXFLAGS}
        $${TGT}_DEFS       := $${TGT_DEFS}
        $${TGT}_INCDIRS    := $$(abspath $$(call CANONICAL_PATH,$$(call QUALIFY_PATH,$${DIR},$${TGT_INCDIRS})))
        $${TGT}_LDFLAGS    := $${TGT_LDFLAGS}
        $${TGT}_LINKER     := $${TGT_LINKER}
        $${TGT}_INSTALL    := $${TGT_INSTALL}
        $${TGT}_TEST       := $${TGT_TEST}
        $${TGT}_PRIORCLEAN := $${TGT_PRIORCLEAN}
        $${TGT}_POSTCLEAN  := $${TGT_POSTCLEAN}
        $${TGT}_PRIORMAKE  := $${TGT_PRIORMAKE}
        $${TGT}_POSTMAKE   := $${TGT_POSTMAKE}
        $${TGT}_PREREQS    := $$(addprefix $${TARGET_DIR}/,$${TGT_PREREQS})
    endif

    # dir_stack ${DIR_STACK}
    ifdef DEBUG
        $$(info **** included $(strip ${1}) for target: $${TARGET})
    endif

    # Push the current target onto the target stack.
    TGT_STACK := $$(call PUSH,$${TGT_STACK},$${TGT})

    ifneq "$$(strip $${SOURCES})" ""
        # This makefile builds one or more objects from source. Validate the
        # specified sources against the supported source file types.
        BAD_SRCS := $$(strip $$(filter-out $${ALL_SRC_EXTS},$${SOURCES}))
        ifneq "$${BAD_SRCS}" ""
            $$(error Unsupported source file(s) found in ${1} [$${BAD_SRCS}])
        endif

        # Qualify and canonicalize paths.
        SOURCES     := $$(call QUALIFY_PATH,$${DIR},$${SOURCES})
        SOURCES     := $$(abspath $$(call CANONICAL_PATH,$${SOURCES}))
        SRC_INCDIRS := $$(call QUALIFY_PATH,$${DIR},$${SRC_INCDIRS})
        SRC_INCDIRS := $$(abspath $$(call CANONICAL_PATH,$${SRC_INCDIRS}))

        # Save the list of source files for this target.
        $${TGT}_SOURCES += $${SOURCES}

        # Convert the source file names to their corresponding object filenames.
        OBJS := $$(addprefix $${BUILD_DIR}/,$$(addsuffix .o,$$(basename $${SOURCES})))
        # Add the objects to the current target's list of objects, and create
        # target-specific variables for the objects based on any source
        # variables that were defined.
        $${TGT}_OBJS += $${OBJS}
        $${TGT}_DEPS += $${OBJS:%.o=%.P}
        $${OBJS}: SRC_CFLAGS   := $${$${TGT}_CFLAGS}
        $${OBJS}: SRC_CXXFLAGS := $${$${TGT}_CXXFLAGS}
        $${OBJS}: SRC_DEFS     := $$(addprefix -D,$${$${TGT}_DEFS})
        $${OBJS}: SRC_INCDIRS  := $$(addprefix -I,$${$${TGT}_INCDIRS})
    endif

    ifneq "$$(strip $${SUBMAKEFILES})" ""
        # This makefile has submakefiles. Recursively include them.
        $$(foreach MK,$${SUBMAKEFILES},\
           $$(eval $$(call INCLUDE_SUBMAKEFILE,\
                      $$(call CANONICAL_PATH,\
                         $$(call QUALIFY_PATH,$${DIR},$${MK})))))
    endif

    # Reset the "current" target to it's previous value.
    TGT_STACK := $$(call POP,$${TGT_STACK})
    TGT := $$(call PEEK,$${TGT_STACK})

    # Reset the "current" directory to it's previous value.
    DIR_STACK := $$(call POP,$${DIR_STACK})
    DIR := $$(call PEEK,$${DIR_STACK})
endef #INCLUDE_SUBMAKEFILE

# MIN - Parameterized "function" that results in the minimum lexical value of
#   the two values given.
define MIN
$(firstword $(sort ${1} ${2}))
endef

# PEEK - Parameterized "function" that results in the value at the top of the
#   specified colon-delimited stack.
define PEEK
$(lastword $(subst :, ,${1}))
endef

# POP - Parameterized "function" that pops the top value off of the specified
#   colon-delimited stack, and results in the new value of the stack. Note that
#   the popped value cannot be obtained using this function; use peek for that.
define POP
${1:%:$(lastword $(subst :, ,${1}))=%}
endef

# PUSH - Parameterized "function" that pushes a value onto the specified colon-
#   delimited stack, and results in the new value of the stack.
define PUSH
${2:%=${1}:%}
endef

# QUALIFY_PATH - Given a "root" directory and one or more paths, qualifies the
#   paths using the "root" directory (i.e. prepends the root directory name to
#   the paths) except for paths that are absolute.
define QUALIFY_PATH
$(addprefix ${1}/,$(filter-out /%,${2})) $(filter /%,${2})
endef

###############################################################################
#
# Start of Makefile Evaluation
#
###############################################################################

# Older versions of GNU Make lack capabilities needed by NON-RECURSIVE-Makefile.
# With older versions, "make" may simply output "nothing to do", likely leading
# to confusion. To avoid this, check the version of GNU make up-front and
# inform the user if their version of make doesn't meet the minimum required.
MIN_MAKE_VERSION := 3.81
MIN_MAKE_VER_MSG := NON-RECURSIVE-Makefile requires GNU Make ${MIN_MAKE_VERSION} or greater
ifeq "${MAKE_VERSION}" ""
    $(info GNU Make not detected)
    $(error ${MIN_MAKE_VER_MSG})
endif
ifneq "${MIN_MAKE_VERSION}" "$(call MIN,${MIN_MAKE_VERSION},${MAKE_VERSION})"
    $(info This is GNU Make version ${MAKE_VERSION})
    $(error ${MIN_MAKE_VER_MSG})
endif

# Define the source file extensions that we know how to handle.
C_SRC_EXTS := %.c
CXX_SRC_EXTS := %.C %.cc %.cp %.cpp %.CPP %.cxx %.c++
ALL_SRC_EXTS := ${C_SRC_EXTS} ${CXX_SRC_EXTS}

# Initialize global variables.
ALL_TGTS :=
DIR_STACK :=
TGT_STACK :=

# Include the main user-supplied submakefile. This also recursively includes
# all other user-supplied submakefiles.
$(eval $(call INCLUDE_SUBMAKEFILE, ${MAIN}))

# $(info Analyzing All Depdendencies...)
# Define the "all" target (which simply builds all user-defined targets) as the
# default goal.
.PHONY: all
all: $(addprefix ${TARGET_DIR}/,${ALL_TGTS})

# Add a new target rule for each user-defined target.
$(foreach TGT,${ALL_TGTS},\
  $(eval $(call ADD_TARGET_RULE,${TGT})))

# in INCLUDE_SUBMAKEFILE
# OBJS := $$(addprefix $${BUILD_DIR}/$(call CANONICAL_PATH,$${TGT}),$$(addsuffix .o,$$(basename $${SOURCES})))
# in the following rule creation phase
# $(eval $(call ADD_OBJECT_RULE,${BUILD_DIR}/$(call CANONICAL_PATH,${TGT}),${EXT},\
# Add pattern rule(s) for creating compiled object code from C source.
# We want to force make to evaluat them until all c objects are specified
$(foreach TGT,${ALL_TGTS},\
  $(foreach EXT,${C_SRC_EXTS},\
    $(eval $(call ADD_OBJECT_RULE,${BUILD_DIR},${EXT},\
        $${COMPILE_C_CMDS}, $${UNIT_TEST_CMDS}))))


# Add pattern rule(s) for creating compiled object code from C++ source.
$(foreach TGT,${ALL_TGTS},\
  $(foreach EXT,${CXX_SRC_EXTS},\
    $(eval $(call ADD_OBJECT_RULE,$(patsubst %/,%,${BUILD_DIR}/${TGT}),${EXT},$${COMPILE_CXX_CMDS}))))

# Add "clean" rules to remove all build-generated files.
.PHONY: clean
$(foreach TGT,${ALL_TGTS},\
  $(eval $(call ADD_CLEAN_RULE,${TGT})))

# Add "install" rules to add all target to its location.
.PHONY: install
$(foreach TGT,${ALL_TGTS},\
  $(eval $(call ADD_INSTALL_RULE,${TGT})))

# Add "install" rules to add all target to its location.
.PHONY: test
$(foreach TGT,${ALL_TGTS},\
  $(eval $(call ADD_TEST_RULE,${TGT})))

# Include generated rules that define additional (header) dependencies.
$(foreach TGT,${ALL_TGTS},\
  $(eval -include ${${TGT}_DEPS}))

all:
!   @echo all done.

distclean:
!   @echo distclean done.

install:
!   @echo install done.
