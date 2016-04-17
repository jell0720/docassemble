---
layout: docs
title: Roles
short_title: Roles
---

# Interviews with multiple users

**docassemble** allows you to create multi-user interviews.

For example:

* In a legal application, a client uses the interview to answer
  questions about the facts of a case, and then an attorney reviews
  the responses, answers questions about how the law applies to the
  facts, and then the client comes back to the interview to receive a
  legal advice letter.
* If a user's language is not English, a translator will be invited to
  join the interview to translate the user's textual responses into
  English before the interview process is completed.
* Two parties who are negotiating with one another will fill in
  answers to an interview, and when both are done, the interview will
  suggest a resolution based on the answers of both parties.

Multi-user interviews are implemented through the [user login] feature
and three authoring features that were introduced in other sections:

* `role` [modifier]: designates certain questions as being answerable
  only by a particular user (or group of users).
* `default role` [initial block]: sets the `role` modifier for
  questions that do not have a `role` explicitly set.  The `code`
  within this block is run as `initial` code.  The responsibility of
  this `code` is to set the variable `role` depending on the
  circumstances, which can include the identity and privileges of the
  person logged in (which can be determined from the
  `current_info['user']` [dictionary]).
* `event` [variables]: when the current user cannot proceed further
  with the interview because the interview needs input from a
  different user, **docassemble** will display a message for the
  current user.  It finds this message by looking for a question
  marked with `event: role_event`.  [Mako] template commands can be
  used in this question to say different things depending on who the
  current user is and who the new user needs to be.

The following example of a three-role interview demonstrates how
multi-user interviews are created in **docassemble**.

The interview starts with an organizer, who clicks past an
introductory screen and is asked for the e-mail addresses of two
participants who will bid on a contract.  The organizer is then asked
to invite the participants to bid by clicking on a particular link and
logging in.  Once both bidders have entered their bids, the winner
(the participant with the lowest bid) is announced.  Until both
participants have entered bids, users will see a page telling them to
wait and to press the "Check" button to see if both bids have been
made yet (except for bidders who haven't bid yet, who will be asked
for their bids).

{% highlight yaml %}
---
default role: organizer
code: |
  multi_user = True
  role = 'organizer'
  if introduction_made and participants_invited:
    if current_info['user']['is_authenticated']:
      if current_info['user']['email'] == first_person_email:
        role = 'first_person'
      elif current_info['user']['email'] == second_person_email:
        role = 'second_person'
---
event: role_event
question: Waiting on another participant
subquestion: |
  % if 'first_person' in role_needed or 'second_person' in role_needed:
  We are waiting for a participant to put in a bid.
  % else:
  We are waiting for the organizer.
  % endif

  % if not current_info['user']['is_authenticated']:
  If you were invited to participate, please click "Sign in."
  % endif

  Press **Check** to check on the status.
buttons:
  - Check: refresh
---
mandatory: true
code: |
  if role == 'first_person':
    first_person_bid
  if role == 'second_person':
    second_person_bid
  announce_winner
---
field: introduction_made
question: |
  Welcome to a test of the multi-user system!
subquestion:
  This is the start of a test of the multi-user system.
  You are the organizer.  To continue, press **Continue**.
---
code: |
  if first_person_email == second_person_email:
    organizer_messed_up
  else:
    recipients_ok = True
---
field: participants_invited
need: recipients_ok
question: |
  Invite the bidders
subquestion: |
  Ok, organizer, send e-mails to ${ first_person_email } and
  ${ second_person_email } inviting them to submit bids.

  Tell them to go to the following URL:

  [${ interview_url }](${ interview_url })
---
code: |
  interview_url = current_info['url'] + '?i=' + current_info['yaml_filename'] + '&session=' + current_info['session']
---
sets: announce_winner
role:
  - organizer
  - first_person
  - second_person
question: And the winner is...
subquestion: |
  % if first_person_bid < second_person_bid:
  The winning bidder is First Person!
  % elif first_person_bid > second_person_bid:
  The winning bidder is Second Person!
  % else:
  Sorry, no winner.  The bids matched.
  % endif
---
question: |
  What are the e-mail addresses of the participating bidders?
fields:
  - First Person: first_person_email
    datatype: email
  - Second Person: second_person_email
    datatype: email
---
role: first_person
question: |
  How much will you bid for the contract?
fields:
  - Amount: first_person_bid
    datatype: currency
---
role: second_person
question: |
  How much will you bid for the contract?
fields:
  - Amount: second_person_bid
    datatype: currency
---
sets: organizer_messed_up
question: |
  That won't work.
subquestion: |
  Please try again.  This time enter different e-mail addresses
  for the participants.
buttons:
  - Restart: restart
...
{% endhighlight %}

Most of the code is self-explanatory, but a few of the blocks warrant
explanation.

Consider the first block:

{% highlight yaml %}
---
default role: organizer
code: |
  multi_user = True
  role = 'organizer'
  if introduction_made and participants_invited:
    if current_info['user']['is_authenticated']:
      if current_info['user']['email'] == first_person_email:
        role = 'first_person'
      elif current_info['user']['email'] == second_person_email:
        role = 'second_person'
---
{% endhighlight %}

Here, we set the `default role` to `organizer`.  This simply means that
questions in the interview that do not have a `role` specified will
require the `organizer` role.

The `code` is `initial` code, the primary purpose of which is to set
the `role` variable, which is the role of whichever user is currently
in the interview.  This code runs every single time the page loads for
any user.

This code block also sets the [special variable] `multi_user` to
`True`, which tells **docassemble** that multiple users will be using
this interview.  When `multi_user` is `True`, **docassemble** will not
encrypt the answers on the server.  This reduces [security] somewhat,
but is necessary in order for multiple users to participate in the
same interview.

First, note that the `role` for all users will remain `organizer`
until the organizer has seen the introductory page and the
participants have been invited.

Second, note that the flow of the interview is being controlled here.
The references to `introduction_made` and `participants invited` mean
that questions will be asked to define those variables if they are
undefined.  This is the code that causes those questions to appear for
the organizer.  After the role is set, the `mandatory` `code` block
controls the flow of the interview.

Third, note that by requiring `participants invited` to be set before
we consider whether the user's e-mail address is equal to
`first_person_email`, we ensure that the interview flow proceeds the
way we want it to.  Suppose we did not check for `participants
invited` before doing this.  If the organizer was logged in and gave
his own e-mail address as that of a participant, he would assume the
role of a participant before learning the URL that he needs to give to
the other participant.

There are times when you just want **docassemble** to figure out the
interview flow implicitly, and there are times when you want to be
explicit about it.  Setting up roles is one situation where you want
to be pretty explicit, so that you account for all the unexpected
scenarios that may occur.

Another block that warrants explanation is the `mandatory` `code`
block:

{% highlight yaml %}
---
mandatory: true
code: |
  if role == 'first_person':
    first_person_bid
  if role == 'second_person':
    second_person_bid
  announce_winner
---
{% endhighlight %}

This code block also sets a goal for the interview: finding the value
of `announce_winner`.  Note that if we took out the two `if`
statements, the interview could still get done, because
`announce_winner` implicitly asks for both `firth_person_bid` and
`second_person_bid`.  The problem with that (or the inconvenience) is
that `announce_winner` looks for the value of `first_person_bid`
before it looks for the value of `second_person_bid`.  This means that
the second participant would have to wait to enter his bid until the
first participant had done so.  This would be arbitrary and could
cause unnecessary delay.  The additional code here will ask each
participant for his bid regardless of which one is first to log in.

The `interview_url` text looks very complicated, because it is.

{% highlight yaml %}
---
code: |
  interview_url = current_info['url'] + '?i=' + current_info['yaml_filename'] + '&session=' + current_info['session']
---
{% endhighlight %}

The URL that is defined in `interview_url` contains the secret
`session` key of the interview, which was created when the organizer
started the interview.  When someone goes to this URL, they will enter
the interview that is already in progress, whatever the current state
of the interview is.  Note that the URL in the location bar of the web
browser will be shortened after the first page load, but the
interview-specific information in the URL will not be forgotten
(essentially, it is moved from the location bar into a cookie in the
web browser).

It isn't a good practice to include complicated computer code like
this `interview_url` block in your interview [YAML].  (You will see in
the section on [legal applications] that there is a function available
for retrieving the interview URL in a clean way.)  We included the
details here so that we could give you a complete example with no
hidden detail.

In practice, it's a good idea to `include` a question file, such as
`basic-questions.yml` from `docassemble.base`, which provides you with
functions that handle complicated computer code for you.  One of the
functions that `basic-questions.yml` gives you is `interview_url()`,
from the `docassemble.base.legal` module.

If we had included:

{% highlight yaml %}
---
include: basic-questions.yml
---
{% endhighlight %}

then we could have written:

{% highlight yaml %}
  Tell them to go to the following URL:

  [${ interview_url() }](${ interview_url() })
{% endhighlight %}

Then we would not need to have the `interview_url` variable.

# Interviews with an unknown number of users

In the example above, there were two participants in the interview
(other than the organizer): `first_person` and `second_person`.  But
what if you will have more than two participants?  Do you have to
create `role`s up to `ten_thousandth_person`?  No -- there are other
ways to handle multi-user interviews.

Consider the following example, which uses [generic objects]:

{% highlight yaml %}
---
modules:
  - docassemble.base.core
---
objects:
  - respondents: DADict
---
initial: true
code: |
  multi_user = True
  if current_info['user']['is_authenticated']:
    if current_info['user']['email'] not in respondents:
      respondents.setObject(current_info['user']['email'], DAObject)
    user = respondents[current_info['user']['email']]
    final_page
  else:
    must_be_logged_in_page
---
sets: final_page
question: |
  <%
    cat_count = 0
    for email in respondents:
      respondent = respondents[email]
      if respondent is user or hasattr(respondent, 'number_of_cats'):
        cat_count += respondent.number_of_cats
  %>
        
  % if cat_count == 0:
  There are zero cats so far.
  % elif cat_count == 1:
  There is only one cat so far.
  % else:
  There are ${ cat_count } cats in all.
  % endif
subquestion: |
  Share this link with others!

  [${ interview_url }](${ interview_url })
buttons:
  - Check: refresh
---
code: |
  interview_url = current_info['url'] + '?i=' + current_info['yaml_filename'] + '&session=' + current_info['session']
---
generic object: DAObject
question: How many cats do you have?
fields:
  - Number of cats: x.number_of_cats
    datatype: integer
---
sets: must_be_logged_in_page
question: Please log in
subquestion: |
  Please click "Sign in" to continue.  If you do not have
  an account, you can register for one.
buttons:
  - Sign in: signin
...
{% endhighlight %}

This interview asks every user how many cats he or she has, and then
tells the user the total number of cats of all of the interview
respondents.

Note that this interview allows multiple users but does not make use
of the `role` and `default role` features.  The purpose of those
features is to put one user on hold while waiting for input from
another user.  There are some situations, like the above interview,
that do not require one user to wait for another user.  In that case,
it is not necessary to set user roles.

The `initial` code block makes sure that the user is logged in, and
sets the `user` variable to a `DAObject`.

A `DAObject` is the most basic type of **docassemble** object.  Its
definition is in `docassemble.base.core`.  The fact that the `user` is
a `DAObject` means that the `user` can have [attributes] and those
[attributes] can be gathered with [generic object] questions.

The `initial` code block also keeps track of all the users that have
used the interview (i.e. by either starting the interview from scratch
or clicking on the link given by `interview_url`) so that the [Mako]
code in the `final_page` question can loop over all of the users and
tally up the number of cats.

These lines in the `initial` block define the `user` variable and keep
track of each user:

{% highlight yaml %}
if current_info['user']['email'] not in respondents:
  respondents.setObject(current_info['user']['email'], DAObject)
user = respondents[current_info['user']['email']]
{% endhighlight %}

`current_info['user']` is a Python [dictionary] containing information
about the logged-in user.  If the user was not logged in, the `email`
would not be known.  The `email` is a unique identifier for each user
in the login system.

The `objects` block defines `respondents` as an object of type DADict.
A DADict acts much like an ordinary Python [dictionary], except that it
has special properties that allow **docassemble** to set its
attributes using `generic object` questions.

The second line in the excerpt above defines an entry in this
[dictionary], `respondents[current_info['user']['email']]` as a new
object of type DAObject.  The `setObject` method effectively does this:

{% highlight python %}
respondents[current_info['user']['email']] = DAObject()
{% endhighlight %}

However, it does not work to actually write that; the `setObject`
method takes care of the **docassemble** internals that allow
**docassemble** to set undefined attributes.

Note that the `modules` block is necessary in this interview;
otherwise we could not refer to names like `DAObject` and `DADict`.

The [Mako] code contains this line:

{% highlight python %}
if respondent is user or hasattr(respondent, 'number_of_cats'):
  cat_count += respondent.number_of_cats
{% endhighlight %}

The `hasattr` function is a [built-in Python function] that returns
`True` if `respondent` has an attribute called `number_of_cats`, and
`False` if not.  We are saying here that we want to tally the total
number of cats for the user and all respondents who have answered the
question about the number of cats they have.  If we did not exclude
respondents who had not yet indicated their number of cats, then the
user might be asked for the number of cats belonging to a different
respondent.  It would be rare that this would ever happen -- it would
happen if the user checked the number of cats between the time another
respondent logged in and the time the respondent entered his number of
his cats -- but it is important to anticipate and control for rare
cases.

[initial block]: {{ site.baseurl }}/docs/initial.html
[modifier]: {{ site.baseurl }}/docs/modifiers.html
[fields]: {{ site.baseurl }}/docs/fields.html
[Mako]: http://www.makotemplates.org/
[generic object]: {{ site.baseurl }}/docs/objects.html
[generic objects]: {{ site.baseurl }}/docs/objects.html
[attributes]: https://docs.python.org/2/tutorial/classes.html#python-scopes-and-namespaces
[attribute]: https://docs.python.org/2/tutorial/classes.html#python-scopes-and-namespaces
[built-in Python function]: https://docs.python.org/2/library/functions.html#hasattr
[dictionary]: https://docs.python.org/2/tutorial/datastructures.html#dictionaries
[YAML]: https://en.wikipedia.org/wiki/YAML
[user login]: {{ site.baseurl }}/docs/users.html
[variables]: {{ site.baseurl }}/docs/fields.html
[special variable]: {{ site.baseurl }}/docs/special.html
[security]: {{ site.baseurl }}/docs/security.html
[legal applications]: {{ site.baseurl }}/docs/legal.html