# How It Works

No matter what development process your team uses—Kanban, Scrum, or
Waterfall—manageability [depends][measure-or-not] on how fairly and objectively
you reward your most productive programmers. Zerocracy does exactly that: it
measures each person's contribution according to predefined and configurable
bylaws, eliminating favoritism, subjectivity, and emotions.

Zerocracy is non-intrusive: it doesn't tell programmers what to do, when, or
how. Instead, it observes their actions and informs them when they earn or lose
points. Programmers can view their individual contribution statistics in an
HTML summary updated every few hours ([example][vitals]).
They also receive notifications
directly in their GitHub issues ([example][reward]).

As a manager, you can use the points earned by programmers to calculate their
bonuses or even salaries. Even if you don't, the gamification alone will
significantly [improve][effect] team productivity and reduce turnover.

Here's how it works:

1. You create an [account][baza] and get a token.
1. You create a new GitHub Actions workflow.
1. The workflow publishes points earned by each programmer.
1. [Zerocrat][0crat] on GitHub informs programmers when they score.

Currently, it's all free.

[measure-or-not]: https://www.yegor256.com/2020/06/23/individual-performance-metrics.html
[vitals]: https://www.eolang.org/zerocracy/objectionary-vitals.html
[reward]: https://github.com/objectionary/eo/pull/3457#issuecomment-2455183697
[baza]: https://www.zerocracy.com/dash
[judges-action]: https://github.com/zerocracy/judges-action
[effect]: https://www.yegor256.com/2014/09/24/why-monetary-awards-dont-work.html
[0crat]: https://github.com/0crat
