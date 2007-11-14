#!/usr/bin/perl -w
# -*- coding: utf-8; -*-
#
# (C)-IDEALX

package Test::Group;
use strict;
use warnings;

=head1 NAME

Test::Group - Group together related tests in a test suite

=head1 VERSION

Test::Group version 0.09

=cut

our $VERSION = '0.09';

=head1 SYNOPSIS

=for tests "synopsis-success" begin

    use Test::More no_plan => 1;
    use Test::Group;

    test "hammering the server" => sub {
        ok(I_can_connect);
        for(1..1000) {
           ok(I_can_make_a_request);
        }
    }; # Don't forget the semicolon here!

=for tests "synopsis-success" end

=for tests "synopsis-fail" begin

    test "this test group will fail", sub {
        ok 1, "sub test blah";
        is "foo", "bar";                    # Oops!
        ok 1;
        like   "blah blah blah", qr/bla/;
    };

    test "this test will fail but the suite will proceed", sub {
        pass;
        die;
    };

=for tests "synopsis-fail" end

=for tests "synopsis-TODO" begin

    test "a test with TODO in the name is marked TODO" => sub {
          pass("this part is done");
          fail("but I'm not finished with this one yet");
    };

    {
      local $TODO = "Test::More's good old method also works";
      test "this test is not finished yet" => sub {
          pass;
          fail;
      };
    };

=for tests "synopsis-TODO" end

=for tests "synopsis-misc" begin

    # Don't catch exceptions raised in test groups later on
    Test::Group->dont_catch_exceptions;

    # log caught exceptions in /tmp/log
    Test::Group->logfile("/tmp/log");

    # skip the next group of test
    skip_next_test "network not available" if (! Network->available());
    test "bla", sub {
        my $ftp = Net::FTP->new("some.host.name");
        # ...
    };

    begin_skipping_tests "reason";

    test "this test will not run" => sub {
        # ...
    };

    end_skipping_tests;

    # from now on, skip all tests whose names do not match /bla/
    test_only qr/bla/;

=for tests "synopsis-misc" end

=head1 DESCRIPTION

Fed up with counting tests to discover what went wrong in your last
test run?  Tired of squinting at your test source to find out where on
earth the faulty test predicate is called, and what it is supposed to
check for?  Then this module is for you!

I<Test::Group> allows for grouping together related tests in a
standard I<Test::More>-style script. (If you are not already familiar
with L<Test::More>, now would be the time to go take a look.)
I<Test::Group> provides a bunch of maintainability and scalability
advantages to large test suites:

=over

=item *

related tests can be grouped and given a name. The intent of the test
author is therefore made explicit with much less effort than would be
needed to name all the individual tests;

=item *

the test output is much shorter and more readable: only failed
subtests show a diagnostic, while test groups with no problems inside
produce a single friendly C<ok> line;

=item *

no more tedious test counting: running an arbitrarily large or
variable number of tests (e.g. in loops) is now hassle-free and
doesn't clutter the test output.

=back

Authors of I<Test::*> modules may also find I<Test::Group> of
interest, because it allows for composing several L<Test::More>
predicates into a single one (see L</Reflexivity>).


=head1 FEATURES

=head2 Blocking Exceptions

By default, calls to L<perlfunc/die> and other exceptions from within
a test group cause it to fail and terminates execution of the group,
but does not terminate whole script.  This relieves the programmer
from having to worry about code that may throw in tests.

This behavior can be disabled totally using L</dont_catch_exceptions>.
Exceptions can also be trapped as usual using L<perlfunc/eval> or
otherwise from inside a group, in which case the test code of course
has full control on what to do next (this is how one should test error
management, by the way).

When Test::Group is set to block errors (the default setting, see also
L</catch_exceptions>), the error messages are displayed as part of the
test name, which some may not find very readable.  Therefore, one can
use a L</logfile> instead.

=head2 Skipping Groups

I<Test::Group> can skip single test groups or a range of them
(consecutive or matched by a regex), which helps shortening the debug
cycle even more in test-driven programming.  When a test group is
skipped, the code within it is simply not executed, and the test is
marked as skipped wrt L<Test::Builder>.  See L</skip_next_test>,
L</skip_next_tests>, L</begin_skipping_tests>, L</end_skipping_tests>
and L</test_only> for details.

=head2 Reflexivity

Test groups integrate with L<Test::Builder> by acting as a single big
test; therefore, I<Test::Group> is fully reflexive.  A particularly
attractive consequence is that constructing new L<Test::More>
predicates is straightforward with I<Test::Group>.  For example,

=for tests "foobar_ok" begin

    use Test::Group;

    sub foobar_ok {
        my ($text, $name) = @_;
        $name ||= "foobar_ok";
        test $name => sub {
           like($text, qr/foo/, "foo ok");
           like($text, qr/bar/, "bar ok");
        };
    }

=for tests "foobar_ok" end

defines a new test predicate I<foobar_ok> that will DWIM regardless of
the caller's testing style: for "classical" L<Test::Simple> or
L<Test::More> users, I<foobar_ok> will act as just another I<*_ok>
predicate (in particular, it always counts for a single test, honors
L<Test::More/TODO: BLOCK> constructs, etc); and of course, users of
I<Test::Group> can freely call I<foobar_ok> from within a group.

=head2 TODO Tests

As shown in L</SYNOPSIS>, L<Test::More>'s concept of TODO tests is
supported by I<Test::Group>: a group is in TODO state if the $TODO
variable is set by the time it starts, or if the test name contains
the word C<TODO>.  Note, however, than setting $TODO from B<inside>
the test group (that is, B<after> the group starts) will not do what
you mean:

=for tests "TODO gotcha" begin

   test "something" => sub {
       local $TODO = "this test does not work yet";
       pass;                                         # GOTCHA!
       fail;
   };

=for tests "TODO gotcha" end

Here C<pass> is an unexpected success, and therefore the whole test
group will report a TODO success despite the test not actually being a
success (that is, it would B<also> be defective if one were to comment
out the C<local $TODO> line).  This semantics, on the other hand,
DWIMs for marking a B<portion> of the test group as TODO:

=for tests "TODO correct" begin

   test "something" => sub {
       pass;
       {
          local $TODO = "this part does not work yet";
          fail;
       }
   };

=for tests "TODO correct" end

Finally, there is a subtle gotcha to be aware of when setting $TODO
outside a test group (that's the second one, so maybe you should not
do that to begin with).  In this case, the value of $TODO is set to
undef B<inside> the group.  In other words, this test (similar to the
one to be found in L</SYNOPSIS>) will succeed as expected:

=for tests "TODO gotcha 2" begin

    {
      local $TODO = "not quite done yet";
      test "foo" => sub {
          fail;
          pass;              # NOT an unexpected success, as
                             # this is simply a subtest of the whole
                             # test "foo", which will fail.
      };
    }

=for tests "TODO gotcha 2" end

=cut

use 5.004;

use Test::Builder;
BEGIN { die "Need Test::Simple version 0.59 or later, sorry"
            unless Test::Builder->can("create"); }
use IO::File;
use File::Spec;

my $classstate_verbose;
my $classstate_skipcounter;
my $classstate_skipreason;
my $classstate_testonly_reason;
my $classstate_testonly_criteria = sub { 1 };
my $classstate_catchexceptions = 1;
my $classstate_logfile;
my $classstate_logfd;

=head2 FUNCTIONS

All functions below are intended to be called from the test
script. They are all exported by default.

=cut

use Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(test skip_next_test skip_next_tests
                 begin_skipping_tests end_skipping_tests
                 test_only);

=over

=item I<test($name, $groupsub)>

Executes I<$groupsub>, which must be a reference to a subroutine, in a
controlled environment and groups the results of all
L<Test::Builder>-style subtests launched inside into a single call to
L<Test::Builder/ok>, regardless of their number.  If the test group is
to be skipped (as discussed in L</Skipping Groups>), calls
L<Test::Builder/skip> once instead.

In case the test group is B<not> skipped, the first parameter to
L<Test::Builder/ok> and the value of the TODO string during same (see
L<Test::More/TODO: BLOCK>) are determined according to the following
algorithm:

=over

=item 1

if the test group terminates by throwing an exception, or terminates
normally but without calling any subtest, it fails.

=item 2

otherwise, if any subtest failed outside of a TODO block, the group
fails.

=item 3

otherwise, if any subtest B<succeeds> inside of a TODO block, the
group is flagged as an unexpected success.

=item 4

otherwise, if any subtest fails inside of a TODO block, the group
results in a TODO (excused) failure.

=item 5

otherwise, the test group managed to avert all hazards and is a
straight success (tada!!).

=back

If any sub-tests failed in I<$groupsub>, diagnostics will be
propagated using L<Test::Builder/diag> as usual.

The return value of I<test> is 1 if the test group is a success
(including a TODO unexpected success), 0 if it is a failure (including
a TODO excused failure), and undef if the test group was skipped.

=cut

sub test ($&) {
    my ($name, $code) = @_;

    my $Test = Test::Builder->new; # This is a singleton actually -
    # it should read "Test::Builder->the()" with permission from
    # Michael Schwern :-)

    my $subTest = Test::Group::_Runner->new($name, $code);
    $subTest->run();

    if ($subTest->is_skipped) {
        $Test->skip($subTest->skip_reason);
        return;
    }

    if ($subTest->got_exception) {
        my $exn = $subTest->exception();
        my $exntext =
            ( ! defined $exn ? "an undefined exception" :
              eval { $exn->can("stringify") } ? $exn->stringify :
              (ref($exn) && $Data::Dumper::VERSION ) ? do {
                  no warnings "once";
                  local $Data::Dumper::Indent = 1;
                  local $Data::Dumper::Terse = 1;
                  Data::Dumper::Dumper($exn) } :
               "$exn" ? "$exn" : "a blank exception" );
        { local $/ = ""; chomp($exntext); }
        my $message = <<"MESSAGE";
Test ``$name'' died:
$exntext
MESSAGE
        if ($classstate_logfd) {
            print $classstate_logfd $message;
            $Test->diag("test ``$name'' died - "
                    . "see log file: ``$classstate_logfile''");
        } else {
            $Test->diag($message);
        };
        $name = "*died* $name";
    }

    no warnings "redefine";
    my ($OK, $TODO_string) = $subTest->as_Test_Builder_params;
    # I tried to put a "local $TODO = " here, but that didn't work and
    # I lack the patience to dig up the whole story about
    # Test::Builder->caller not doing The Right Thing here (yet
    # elsewhere it does when it apparently shouldn't, e.g. in
    # L</run>).  So here goes a sleazy local-method trick to get the
    # TODO status across to Test::Builder; the trick has an adherence
    # in L</ok>, which see.
    local *Test::Builder::todo = sub { $TODO_string };
    $Test->ok($OK, $name);
    return $OK ? 1 : 0;
}

=item I<skip_next_tests>

    skip_next_tests 5;
    skip_next_tests 5, "reason";

Skips the 5 following group of tests.  Dies if we are currently
skipping tests already.

=item I<skip_next_test>

    skip_next_test;
    skip_next_test "reason";

Equivalent to:

    skip_next_tests 1;
    skip_next_tests 1, "reason";

=item I<begin_skipping_tests>

    begin_skipping_tests
    begin_skipping_tests "reason";

Skips all subsequent groups of tests until blocked by
L</end_skipping_tests>.  Dies if we are currently skipping tests
already.

=item I<end_skipping_tests>

Cancels the effect of L</begin_skipping_tests>. Has no effect if we
are not currently skipping tests.

=cut

sub skip_next_tests {
    my ($counter, $reason) = @_;
    die "ALREADY_SKIPPING" if $classstate_skipcounter;
    $classstate_skipcounter = $counter;
    $classstate_skipreason  = $reason;
    return 1;
}

sub skip_next_test {
    skip_next_tests 1, @_;
}

sub begin_skipping_tests {
    my ($reason) = @_;
    die "ALREADY_SKIPPING" if $classstate_skipcounter;
    $classstate_skipcounter = -1;
    $classstate_skipreason = $reason;
    return 1;
}

sub end_skipping_tests {
    $classstate_skipcounter = 0;
    return 1;
}

=item I<test_only>

    test_only "bla()", "reason";
    test_only qr/^bla/;
    test_only sub { /bla/ };

Skip all groups of tests whose name does not match the criteria.  The
criteria can be a plain string, a regular expression or a function.

    test_only;

Resets to normal behavior.

=cut

sub test_only (;$$) {
    my ($criteria, $reason) = @_;

    $classstate_testonly_reason = $reason;

    if (!defined $criteria) {
        $classstate_testonly_criteria = sub { 1 };
    } elsif (!ref $criteria) {
        $classstate_testonly_criteria = sub { $_[0] eq $criteria };
    } elsif (ref $criteria eq "Regexp") {
        $classstate_testonly_criteria = sub { $_[0] =~ /$criteria/ };
    } elsif (ref $criteria eq "CODE") {
        $classstate_testonly_criteria = $criteria;
    }
}

=back

=head1 CLASS METHODS

A handful of class methods are available to tweak the behavior of this
module on a global basis. They are to be invoked like this:

   Test::Group->foo(@args);

=over

=item I<verbose($level)>

Sets verbosity level to $level, where 0 means quietest. For now only 0
and 1 are implemented.

=cut

sub verbose { shift; $classstate_verbose = shift }

=item I<catch_exceptions()>

Causes exceptions thrown from within the sub reference passed to
L</test> to be blocked; in this case, the test currently running will
fail but the suite will proceed. This is the default behavior.

Note that I<catch_exceptions> only deals with exceptions arising
inside I<test> blocks; those thrown by surrounding code (if any) still
cause the test script to terminate as usual unless other appropriate
steps are taken.

=item I<dont_catch_exceptions()>

Reverses the effect of L</catch_exceptions>, and causes exceptions
thrown from a L</test> sub reference to be fatal to the whole suite.
This only takes effect for test subs that run after
I<dont_catch_exceptions()> returns; in other words this is B<not> a
whole-script pragma.

=cut

sub catch_exceptions { $classstate_catchexceptions = 1; }
sub dont_catch_exceptions { $classstate_catchexceptions = 0; }

=item I<logfile($classstate_logfile)>

Sets the log file for caught exceptions to F<$classstate_logfile>.
From this point on, all exceptions thrown from within a text group
(assuming they are caught, see L</catch_exceptions>) will be written
to F<$classstate_logfile> instead of being passed on to
L<Test::More/diag>. This is very convenient with exceptions with a
huge text representation (say an instance of L<Error> containing a
stack trace).

=cut

sub logfile {
    my $class = shift;
    $classstate_logfile  = shift;
    $classstate_logfd    = new IO::File("> $classstate_logfile") or
        die "Cannot open $classstate_logfile";
}

=back

=begin internals

=head1 INTERNALS

=head2 Test::Group::_Runner internal class

This is an internal class whose job is to observe the tests in lieu of
the real I<Test::Builder> singleton (see L<Test::Builder/new>) during
the time the I<$groupsub> argument to L</test> is being run.
Short-circuiting L<Test::Builder> involves a fair amount of black
magic, which is performed using the
L</Test::Builder::_HijackedByTestGroup internal class> as an
accomplice.

=over

=cut

package Test::Group::_Runner;

=item I<new($name, $sub)>

Object constructor; constructs an object that models only the state of
the test group $sub that is about to be run.  This
I<Test::Group::_Runner> object is available by calling L</current>
from $sub, while it is being executed by L</run>.  Afterwards, it can
be queried using L</subtests> and other methods to discover how the
test group run went.

=cut

sub new {
    my ($class, $name, $code) = @_;

    my $self = bless {
                      name     => $name,
                      code     => $code,
                      subtests => [],
                     }, $class;
    # Stash the TODO state on behalf of L</as_Test_Builder_params>,
    # coz we're going to muck with $TODO soon.  Warning, ->todo
    # returns 0 instead of undef if there is no TODO block active:
    my $T = Test::Builder->new;
    $self->{in_todo} = $T->todo if $T->todo;

    # For testability: test groups run inside a mute group are mute as
    # well.
    $self->mute(1) if ($class->current &&
                       $class->current->mute);

    return $self;
}

=item I<run()>

Executes the $sub test group passed as the second parameter to
L</new>, monitoring the results of the sub-tests and stashing them
into L</subtests>.  Invoking C<< ->new($name, $sub) >> then C<<
->run() >> is the same as running </test> with the same parameters,
except that I<test()> additionally passes along the test group results
to L<Test::Builder>.

=cut

sub run {
    my ($self) = @_;

    if ($classstate_skipcounter) {
        $classstate_skipcounter--;
        $self->_skip($classstate_skipreason);
        undef $classstate_skipreason unless $classstate_skipcounter;
        return $self;
    } elsif (! $classstate_testonly_criteria->($self->{name})) {
        $self->_skip($classstate_testonly_reason);
        return $self;
    }

    Test::Builder->new->diag("Running group of tests - $self->{name}")
        if ($classstate_verbose);

    my ($exn);

    my ($callerpack) = caller(1); # Accounting for one stack frame for
                                  # L</test>

    $self->_hijack();    # BEGIN CRITICAL SECTION
    my $exception_raised = !
        $self->_run_with_local_TODO($callerpack, $self->{code});
    $self->_unhijack();  # END CRITICAL SECTION

    if ($exception_raised) {
        if ($classstate_catchexceptions) {
            $self->_record_exception();
        } else {
            die $@; # Rethrow
        }
    }

    return; # No useful return value yet
}

=item I<current()>

=item I<current($newcurrent)>

Class method, gets or sets the current instance of
I<Test::Group::_Runner> w.r.t. the current state of the L</_hijack>
/ L</_unhijack> call stack.  If the stack is empty, returns undef.

=cut

{
    my $current;

    sub current {
        if (@_ == 1) {
            return $current;
        } else {
            $current = $_[1];
        }
    }
}

=item I<orig_blessed()>

Returns the class in which C<< Test::Builder->new >> was originally
blessed just before it got L</_hijack>ed: this will usually be
C<Test::Builder>, unless something really big happens to Perl's
testing infrastructure.

=cut

sub orig_blessed {
    my $self = shift;
    return $self->{reblessed_from} if defined $self->{reblessed_from};
    # Calls recursively:
    return $self->{parent}->orig_blessed if defined $self->{parent};
    return; # Object not completely constructed, should not happen
}

=item I<mute()>

=item I<mute($bool)>

Gets or sets the mute status (false by default).  This method is not
(yet) made visible from L<Test::Group> proper; it is used in the test
suite (see L<testlib/test_test>) so as not to scare the systems
administrator with lots of (expected) failure messages at C<Build
test> time.

=cut

sub mute {
    my ($self, @mute) = @_;
    if (@mute) {
        $self->{mute} = $mute[0];
    } else {
        return $self->{mute};
    }
}

=item I<ok($status)>

=item I<ok($status, $testname)>

=item I<skip($reason)>

Called from within the group subs by virtue of
L</Test::Builder::_HijackedByTestGroup internal class> delegating both
methods to us.  Works like L<Test::Builder/ok>
resp. L<Test::Builder/skip>, except that the test results are stashed
away as part of the group result instead of being printed at once.

=cut

# The code was copied over from L<Test::Builder/ok>, and then
# simplified and refactored.
sub ok {
    my ($self, $status, $testname) = @_;

    # Coerce the arguments into being actual scalars (not objects)
    $status = $status ? 1 : 0;
    $testname = substr($testname, 0) if defined $testname; # Stringifies

    # Use the actual Test::Builder->todo to get at the TODO status.
    # This is both elegant and necessary for recursion, because
    # L</test> localizes this same method in order to fool
    # Test::Builder about the TODO state.
    my $T = Test::Builder->new;
    my($pack, $file, $line) = $T->caller;
    my $todo = $T->todo($pack);
    if (defined $todo) {
        $todo = substr($todo, 0); # Stringifies
        $todo = undef if $todo eq "0";  # Yes, that's how
                                        # Test::Builder->todo works.
    }

    my $result = { status => $status };
    $result->{todo} = $todo if defined($todo);
    push @{$self->{subtests}}, $result;

    # Report failures only, as Test::Builder would
    if( ! $status && ! $self->mute ) {
        my $msg = $todo ? "Failed (TODO)" : "Failed";
        $T->_print_diag("\n") if $ENV{HARNESS_ACTIVE};

	if( defined $testname ) {
	    $T->diag(qq[  $msg test '$testname'\n]);
	    $T->diag(qq[  in $file at line $line.\n]);
	} else {
	    $T->diag(qq[  $msg test in $file at line $line.\n]);
	}
    }

    return $status;
}


sub skip {
    my ($self, $reason) = @_;
    push @{$self->{subtests}}, { status => 1 };
}

=item I<diag(@messages)>

Called from within the group subs by virtue of
L</Test::Builder::_HijackedByTestGroup internal class> delegating it
to us.  If this runner object is L</mute>, does nothing; otherwise,
works like L<Test::Builder/diag>.

=cut

sub diag {
    my ($self, @msgs) = @_;
    return if ($self->{mute});
    my $origdiag = Test::Builder->can("diag");
    $origdiag->(Test::Builder->new, @msgs);
}

=item I<subtests()>

After the test is run, returns a list of hash references, each
indicating the status of a subtest that ran during L</run>. The
following keys may be set in each returned hash:

=over

=item I<status> (always)

A boolean indicating whether the subtest was successful.

=item I<todo> (may not exist)

A string indicating an excuse why the test might have failed.

=back

In scalar context, returns the number of subtests that occured in the
group run.

The list of I<subtests()> is appended to by L</ok> as the test group
progresses.

=cut

sub subtests { @{shift->{subtests}} }

=item I<unexcused_failure_subtests>

Returns the subset of the L</subtests> that have a false I<status> and
no I<todo>.  Such tests cause the test group to fail as a whole.  In
scalar context, returns the number of such unexcused failures.

=cut

sub unexcused_failure_subtests {
    grep { (! $_->{status}) && ! exists($_->{todo}) }
        (shift->subtests);
}

=item I<unexpected_success_subtests>

Returns the subset of the L</subtests> that have a true I<status> and
also a I<todo>.  Such tests are called B<unexpected successes> and are
signaled both by L<Test::Harness> and I<Test::Group> (see respectively
L<Test::More/TODO: BLOCK> and L</TODO Tests>). In scalar context,
returns the number of such unexpected successes.

=cut

sub unexpected_success_subtests {
    grep { $_->{status} && exists($_->{todo}) } (shift->subtests);
}

=item I<todo_subtests>

Returns the subset of the L</subtests> that have a I<todo>, regardless
of whether they are L</unexpected_success_subtests>.

=cut

sub todo_subtests {
    grep { exists $_->{todo} } (shift->subtests)
}

=item I<got_exception()>

Returns true iff there was an exception raised while the test group
sub ran (that is, whether L</_record_exception> was called once for
this object).

=cut

sub got_exception { defined shift->{exception} }

=item I<exception()>

Returns the value of the exception passed to L</_record_exception>.
Note that it is possible for I<exception()> to return undef, yet
I<got_exception()> to return true (that is, an exception whose value
is undef): this can happen when a DESTROY block that runs after the
initial exception in turn throws another exception (remedy: one should
use "local $@;" at the beginning of every sub DESTROY).

=cut

sub exception { shift->{exception} }

=item I<is_skipped()>

Returns true iff this test was skipped and did not actually run.

=item I<skip_reason()>

Returns the reason that was stipulated by the test writer for skipping
this test.  Note that I<skip_reason()> may be undef even if
L</skipped> is true.

=cut

sub is_skipped { exists shift->{skipreason} }
sub skip_reason { shift->{skipreason} }

=item I<as_Test_Builder_params>

Returns a ($OK_status, $TODO_string) pair that sums up what we should
tell L<Test::Builder> about this test (assuming that it actually ran,
as opposed to L</is_skipped> tests).  The returned values implement
the algorithm detailed in L</test>; they are designed to be used
respectively as the first parameter to L<Test::Builder/ok>, and as
what L<Test::Builder/todo> should be tricked into returning during the
call to said I<< Test::Builder->ok >> (have a look at the source code
for L</test> if you want to see that trick in action).

I<as_Test_Builder_params> will do its best to sum up the status of the
multiple tests ran inside this group into what amounts to a single
call to L<Test::Builder/ok>, according to the following table:

 Situation                       $OK_status      defined($TODO_string)

 Real success                       true                 false

 Success, but TODOs seen            false                true
 within the group

 Unexpected TODO success(es)        true                 true
 within the group

 Failed test in group,              false                false
 or no tests run at all

Finally, if the test group as a whole is running in a TODO context (by
virtue of $TODO being defined at L</test> invocation time, or the test
having the word TODO in the name, as discussed in L</TODO Tests>),
$TODO_string will be set if it isn't already, possibly transforming
the fate of the test group accordingly.

=cut

sub as_Test_Builder_params {
    my ($self) = @_;

    die <<"MESSAGE" if ! wantarray;
INCORRECT CALL: array context only for this method.
MESSAGE

    my ($OK, $TODO_string);
    if ($self->is_skipped) {
        die <<"MESSAGE";
INCORRECT CALL: this method should not be called for skipped tests
MESSAGE
    } elsif ($self->got_exception ||
             !($self->subtests) ||
             $self->unexcused_failure_subtests) {
        ($OK, $TODO_string) = (0, undef);
    } elsif ($self->unexpected_success_subtests) {
        ($OK, $TODO_string) = (1, $self->_make_todo_string
                               ($self->unexpected_success_subtests));
    } elsif ($self->todo_subtests) {
        ($OK, $TODO_string) =
            (0, $self->_make_todo_string($self->todo_subtests));
    } else {
        ($OK, $TODO_string) = (1, undef); # Hurray!
    }
    if (! defined $TODO_string) {
        $TODO_string = $self->{name} if $self->{name} =~ m/\bTODO\b/;
        $TODO_string = $self->{in_todo} if $self->{in_todo};
    }
    return ($OK, $TODO_string);
}

=item I<_hijack()>

Hijacks L<Test::Builder> for the time the test group sub is being run,
so that we may capture the calls to L<Test::Builder/ok> and friends
made from within the group sub.  L</_unhijack> cancels this behavior.

When called while L</current> is undef, C<< Test::Builder->new >> is
(ahem) temporarily reblessed into the
I<Test::Builder::_HijackedByTestGroup> package, so that any method
calls performed subsequently against it will be routed through
L</Test::Builder::_HijackedByTestGroup internal class> where they can
be tampered with at will.  This works even if third-party code
happened to hold a reference to C<< Test::Builder->new >> before
I<_hijack> was called.

If on the other hand L</current> was already defined before entering
I<_hijack>, then a B<nested hijack> is performed: this is to support
nested L</test> group subs.  In this case, the returned object behaves
mostly like the first return value of I<_hijack> except that its
L</_unhijack> method has no effect.

=cut

sub _hijack {
    my ($self) = @_;

    my $class = ref($self);
    if (defined $class->current) {    # Nested hijack
        $self->{parent} = $class->current;
    } else {                          # Top-level hijack
        $self->{orig_testbuilder} = Test::Builder->new;
        $self->{reblessed_from} = ref($self->{orig_testbuilder});
        bless($self->{orig_testbuilder},
              "Test::Builder::_HijackedByTestGroup");
    }

    # The following line of code must be executed immediately after
    # the reblessing above, as the delegating stubs (L</ok>, L</skip>
    # and L</diag> below) need ->current() to be set to work:
    $class->current($self);
}

=item I<_unhijack()>

Unbuggers the C<< Test::Builder->new >> singleton that was reblessed
by L</_hijack>, so that it may resume being itself, or pops one item
from the L</current> stack in case of a nested hijack.

=cut

sub _unhijack {
    my ($self) = @_;
    if (defined($self->{orig_testbuilder})) { # Top-level unhijack
        $self->current(undef);
        bless $self->{orig_testbuilder}, $self->{reblessed_from};
    } else {
        # Nested unhijack
        $self->current($self->{parent});
    }
    1;
}

=item I<_run_with_local_TODO($callerpack, $sub)>

Invokes the test sub $sub while temporarily setting the variable
C<${${callerpack}::TODO}> to undef, thereby implementing the
local-TODO semantics described in L</TODO Tests>.  Returns true if
$sub completed, and false if $sub threw an exception (that is
thereafter available in $@ as usual).

I<_run_with_local_TODO> is guaranteed not to throw an exception
itself, so that it is safe to use it in a critical section opened by
calling L</_hijack> and closed by calling L</_unhijack>.

=cut

sub _run_with_local_TODO {
    my ($self, $callerpack, $sub) = @_;
    ## Locally sets $TODO to undef, see POD snippet "TODO gotcha 2".
    ## I used to do
    #     no strict 'refs';
    #     local ${$callerpack . '::TODO' };
    ## but this doesn't work in 5.6 ("Can't localize through a reference")
    my $TODOref = do { no strict "refs"; \${$callerpack . '::TODO' } };
    my $TODOorig = $$TODOref;
    $$TODOref = undef;

    my $retval = eval { $sub->(); 1; };
    $$TODOref = $TODOorig;
    return $retval;
}

=item I<_skip($reason)>

Private setter called from L</run> when the test sub is not to be
called at all.  $reason is the reason why the test is being skipped
(probable causes are L</skip_next_test>, L</skip_next_tests>,
L</test_only> and friends).

=cut

sub _skip {
    my ($self, $reason) = @_;

    $self->{skipreason} = $reason;
}

=item I<_record_exception()>

Memorizes the exception that was raised by the group sub that just
run.  The exception is looked for in variables C<$@> and
C<$Error::THROWN>.  TODO: add support for other popular exception
management classes.

=cut

sub _record_exception {
    my ($self) = @_;
    $self->{exception} =
        (  (ref($@) || (defined($@) && length($@) > 0)) ? $@ :
           # Factor L<Error> in (TODO: add L<Exception::Class> as
           # well):
           defined($Error::THROWN) ? $Error::THROWN :
           undef  );
}

=item I<_make_todo_string(@subtests)>

Pretty-prints an appropriate string to return as the second element in
the returned list on behalf of L</as_Test_Builder_params>.  @subtests
are the TODO sub-tests that the caller wants to talk about (depending
on the situation, that would be all the L</todo_subtests>, or only the
L</unexpected_success_subtests>).

=cut

sub _make_todo_string {
    my ($self, @subtests) = @_;
    return join(", ", map { $_->{todo} || "(no TODO explanation)" }
                @subtests);
}

=back

=head2 Test::Builder::_HijackedByTestGroup internal class

This is an internal subclass of L<Test::Builder> used as an accomplice
by L</_hijack> to hijack the method calls performed upon the
Test::Builder singleton (see L<Test::Builder/new>) by the various
testing modules from the CPAN, e.g. L<Test::More>, L<Test::Pod> and
friends.  It works almost the same as the real thing, except for the
following method calls:

=over

=cut

package Test::Builder::_HijackedByTestGroup;
use base "Test::Builder";

=item I<ok>

=item I<skip>

=item I<diag>

These methods are delegated to the L</current> instance of
I<Test::Group::_Runner>.

=cut

foreach my $delegated (qw(ok skip diag)) {
    no strict "refs";
    *{$delegated} = sub {
        my $self = shift;
        unshift(@_, Test::Group::_Runner->current);
        goto &{"Test::Group::_Runner::".$delegated};
    };
}

=back

=end internals

=head1 BUGS

This class uses a somewhat unhealthy dose of black magic to take over
control from L<Test::Builder> when running inside a L</test> group
sub.  While the temporary re-blessing trick used therein is thought to
be very robust, it is not very elegant. Some kind of plugin mechanism
for Test::Builder->new should be designed, implemented and used
instead.

=head1 SEE ALSO

L<Test::Simple>, L<Test::More>, L<Test::Builder>, and friends

The C<perl-qa> project, L<http://qa.perl.org/>.

=head2 Similar modules on CPAN

L<Test::Class> can be used to turn a test suite into a full-fledged
object class of its own, in xUnit style.  It also happens to support a
similar form of test grouping using the C<:Test(no_plan)> or C<:Tests>
attributes.  Switching over to I<Test::Class> will make a test suite
more rugged and provide a number of advantages, but it will also
dilute the "quick-and-dirty" aspect of .t files somewhat. This may or
may not be what you want: for example, the author of this module
enjoys programming most when writing tests, because the most infamous
Perl hacks are par for the course then :-).  Anyway TIMTOWTDI, and
I<Test::Group> is a way to reap some of the benefits of I<Test::Class>
(e.g. running only part of the test suite) without changing one's
programming style too much.

=head1 AUTHORS

Dominique Quatravaux <domq@cpan.org>

Nicolas M. ThiE<eacute>ry <nthiery@users.sf.net>

=head1 LICENSE

Copyright (C) 2004 by IDEALX <http://www.idealx.com>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.1 or,
at your option, any later version of Perl 5 you may have available.

=cut

1;