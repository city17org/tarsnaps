TARSNAPS(8) - System Manager's Manual

# NAME

**tarsnaps** - automate tarsnap backups

# SYNOPSIS

**tarsnaps**
\[**-d**&nbsp;*max*&nbsp;**-m**&nbsp;*max*&nbsp;**-w**&nbsp;*max*]
*target&nbsp;...*  
**tarsnaps**
**-v**

# DESCRIPTION

**tarsnaps**
is a utility that is designed to be run once a day from
cron(8)
and creates a
tarsnap(1)
backup of the files or directories passed as
*target*.
Weekly and monthly archives are created automatically when a daily backup is
taken, and the day matches a
*Sunday*
or the
*1st*
of the month, respectively.

The maximum number of stored archives can be set individually for the daily,
weekly, and monthly backups by specifying the
*max*
value for each.
Once the number of stored archives exceeds this value the oldest are deleted
first.

If
*max*
if not defined, then all archives are stored.
If
*max*
is defined as
**0**
then the backup, if applicable, is not taken and any stored archives
are deleted.
If all values for
*max*
are defined as
**0**
then all archives created by
**tarsnaps**
are deleted, the user is prompted to confirm this action before
continuing.

The options are as follows:

**-d** *max*

> Maximum number of daily archives to keep.

**-m** *max*

> Maximum number of monthly archives to keep.

**-v**

> Display version information and exit.

**-w** *max*

> Maximum number of weekly archives to keep.

# EXIT STATUS

The **tarsnaps** utility exits&#160;0 on success, and&#160;&gt;0 if an error occurs.

# EXAMPLES

The following are example
crontab(5)
entries of a daily backup.

Keep 10 daily, 6 weekly and 12 monthly archives.

	0 22 * * * /usr/local/bin/tarsnaps -d 10 -w 6 -m 12 /etc /home

Keep 28 daily, no weekly and all monthly archives.

	0 22 * * * /usr/local/bin/tarsnaps -d 28 -w 0 /etc /home

# SEE ALSO

tarsnap(1),
crontab(5),
tarsnap.conf(5),
cron(8)

# AUTHORS

Sean Davies &lt;[sean@city17.org](mailto:sean@city17.org)&gt;

# CAVEATS

All items to be backed up should be included in a single job.
**tarsnaps**
assumes it is only being run once per host and does not distinguish between
archives created with different input.
