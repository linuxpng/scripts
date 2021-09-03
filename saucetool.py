#! /usr/bin/python

"""
This is a quick program to parse and report differences between installed RPMs on
two systems.  To use it, give the program the path to sosreports that are to be
compared:

    ./rpmdiff.py /path/to/sos1 /path/to/sos2 /path/to/sos3 [....]

Note:  These are paths to directories, not individual files!
"""

#TODO: There is minimal error handling.

#################################################
# Imports
#################################################

import sys
import re
import argparse
from collections import defaultdict


#################################################
# Functions
#################################################

# ==========| Data structure methods/helpers

# Set up a factory
def tree():
    """
    Factory that creates a defaultdict that also uses this factory
    """
    return defaultdict(tree)


# Put a list into the tree, creating any keys that don't exist
def insert(tree, tokens):
    for t in tokens:
        tree = tree[t]


# ==========| Regex functions

def split_with_regex(s, regex, errlog, hostname):
    """
    Generic function to split strings into a list with the passed in regular expression
    :param s:  String to split
    :param regex:  Regex to use
    :param errlog:  Record any unsplit strings
    :param hostname:  Host that provided the string
    :return:  List of values from the string
    """

    result = filter(None, re.split(regex, s))
    # TODO: This should probably be passed like the regex instead of global
    # First filter out but preserve the data to be inserted into the tree
    result = filter(lambda item: item not in filter_list, result)
    # TODO: This should probably be passed like the regex instead of global
    # Next, if we find an excluded pattern, just return a None string
    if [item for item in result if any(excl in item for excl in excluded)]:
        return None
    # Finally, if the length of the resulting list is 1, then we know it was not split.
    #   Record the vaule in the error list and do not add the value to the compare tree
    if len(result) == 1:
        if hostname in errlog.keys():
            errlog[hostname].append(result[0])
        else:
            errlog[hostname] = []
            errlog[hostname].append(result[0])
        return None
    return result


# ==========| Parse into data structures

def parse_data_to_tree(tree, regex, errlog, data_list, hostname):
    """
    Fills a passed in dictionary, using RPM names split at each '-'.  Hostnames are
    put as leaf values.
    Works on passed in lists or files.
    """
    for line in data_list:
        # Send the data split without the date
        tokens = split_with_regex(line.strip(), regex, errlog, hostname)
        # Append hostname before insertion
        try:
            tokens.append(hostname)
            # Add each token on the list to the tree
            insert(tree, tokens)
        # Here we only want to avoid a traceback for an unhandled RPM name.  We have
        #   already recorded the offending RPM in a list.
        except AttributeError:
            continue


# ==========| Generic helpers

def get_hostname(sos_path):
    return open(sos_path + '/hostname', 'r').read().strip() + '-' + \
         ''.join(open(sos_path + '/date', 'r').read().strip()[4:19].replace(' ', '-'))


def print_tree(data_tree):
    """
    Any 'tree' data structure can be visualized with JSON using the function
    """
    import json
    print json.dumps(data_tree, sort_keys=True, indent=2)


# ==========| Argparse setup

# Options for argument parsing
def add_arguments(opts):
    """
    Function to handle the argument parsing and keep the code separate/readable
    """
    opts.add_argument('path', metavar='path', type=str,
                      action='append', nargs='*',
                      help='Path to sosreport directory')


#################################################
# Definitions
#################################################

# Base data
opts = argparse.ArgumentParser()
hosts = []

# Filter list, these tokens will be removed from lists being inserted into the tree
filter_list = ['=']

# Tokens which exclude the data record from tree addition.
excluded = ['kernel.sched_domain.cpu']

# Data for RPM operations
rpm_compare_tree = tree()
rpm_split_errlog = {}

# Data for sysctl operation
sysctl_compare_tree = tree()
sysctl_split_errlog = {}


#################################################
# Regular expressions
#################################################

"""
This will split the RPM (hopefully) into the 'name' component, the full version 
info, and the release and arch info.  Result returned as a list.
>> Note the outer parenthesis, they are necessary to keep re.split from
consuming the separator (version info in this case).
"""
rpm_split_regex = r'-([\d\-.]+(?:git|svn|git[\w\d]+|cvs)?[\d\-.]+)(el\d_?\d?.*|(?:el\d_?\d?|rhel\d)?.x86_64|(?:el\d)?.noarch|.\(none\)|i386)'

# Curently using original regex, this is for experimentation.
rpm_split_regex2 = '-([\d\-.]+(?:git|svn|git[\w\d]+|cvs)?[\d\-.]+)(el\d_?\d{,3}.?\d?.[\w]+|(?:el\d_?\d?|rhel\d)?.x86_64|(?:el\d)?.noarch|.\(none\)|i386)'

# Regex used with sysctl file
sysctl_split_regex = r'(=)'

#################################################
# Main
#################################################

add_arguments(opts)
run_opts = opts.parse_args()
sos_targets = run_opts.path[0]

# Make sure we got at least 2 sosreports on the command line
if len(run_opts.path[0]) <= 1:
    print("\n\tOnly one path supplied, please specify a path to 2 sosreport directories.\n\n")
    sys.exit(1)

# Get all the hostnames
for sos in sos_targets:
    try:
        hn = get_hostname(sos)
        hosts.append(hn)
    except IOError:
        print("\n\tError attempting access to files in the following provided path:\n\t\t%s\n\tAttempting to "
              "continue...\n" % sos)

# If we weren't able to read/parse more than one unique hostname we should stop
if len(set(hosts)) <= 1:
    print("\nERROR: Unable to parse enough hostnames, check the provided paths.")
    print ("\t2 unique sosreports are required to compare.\n")
    sys.exit(1)

# Parse the RPM data into the tree.  Paths are in sos_targets as a list.
#   This (or any other tree) can be visualized with the 'print_tree" helper function
#
# TODO: There is really no error checking, so if the files are missing just complain
#         as long as there are at least 2 valid hosts provided
for sos_path in sos_targets:
    try:
        hn = get_hostname(sos_path)
        f = open(sos_path + '/installed-rpms', 'r')
        # create list from file so we can split date from RPM strings
        data = []
        for line in f.readlines():
            data.append(line.split()[0])
        # parse list into the tree
        parse_data_to_tree(rpm_compare_tree, rpm_split_regex, rpm_split_errlog, data, hn)
    except IOError:
        print("\n\tError attempting access to files in the following provided path:\n\t\t%s\n\tAttempting to "
              "continue...\n" % sos_path)

# Count all the RPMs that could not be parsed by the regex
unique_set = []
for host in rpm_split_errlog:
    unique_set += rpm_split_errlog[host]

# List all unparsed RPMs by host
print("\nTotal number unique RPMs that the regex was unable to handle:\t%d" % len(set(unique_set)))
print("List of unparsed RPMs by host.  IMPORTANT!:  These RPMs were not part of the comparison:\n")
for host in rpm_split_errlog:
    print("%s:" % host)
    for rpm in rpm_split_errlog[host]:
        print("\t%s" % rpm)
    print('\n')

print("\nNow listing all differences:\n")

output = ""
for rpm in sorted(rpm_compare_tree):
    flag = False
    output = rpm + '\n'
    for version in rpm_compare_tree[rpm]:
        for relarch in rpm_compare_tree[rpm][version]:
            # Is this RPM version on all hosts or not?
            if len(rpm_compare_tree[rpm][version][relarch]) != len(set(hosts)):
                flag = True
                output += "\t%s%s\n" % (version, relarch)
                for host in rpm_compare_tree[rpm][version][relarch]:
                    output += "\t\t%s\n" % host
    if flag:
        print output

#########################################################################

# Parse the sysctl data into the tree.  Paths are in sos_targets as a list.
#
# TODO: There is really no error checking, so if the files are missing just complain
#         as long as there are at least 2 valid hosts provided
for sos_path in sos_targets:
    try:
        hn = get_hostname(sos_path)
        f = open(sos_path + '/sos_commands/kernel/sysctl_-a', 'r')
        parse_data_to_tree(sysctl_compare_tree, sysctl_split_regex, sysctl_split_errlog, f, hn)
    except IOError:
        print("\n\tError attempting access to files in the following provided path:\n\t\t%s\n\tAttempting to "
              "continue...\n" % sos_path)

# Count all the RPMs that could not be parsed by the regex
unique_set = []
for host in sysctl_split_errlog:
    unique_set += sysctl_split_errlog[host]

# List all unparsed sysctl values by host
print("\nTotal number unique sysctl values the regex was unable to handle:\t%d" % len(set(unique_set)))
print("List of unparsed sysctl values by host.  IMPORTANT!:  These values were not part of the comparison:\n")
for host in sysctl_split_errlog:
    print("%s:" % host)
    for sysctl in sysctl_split_errlog[host]:
        print("\t%s" % sysctl)
    print('\n')

print("\nNow listing all differences:\n")

# Print the output string if the number of hosts for each sysctl value does not
#  equal the total number of hosts.
for sysctl in sysctl_compare_tree:
    flag = False
    output = "%s\n" % sysctl
    for value in sysctl_compare_tree[sysctl]:
        if len(sysctl_compare_tree[sysctl][value]) != len(hosts):
            for host in sysctl_compare_tree[sysctl][value]:
                flag = True
                output += "\t%s has set: %s\n" % (host, value)
    if flag:
        print output


