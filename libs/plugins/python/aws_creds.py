#!/usr/bin/env python3
import configparser
import argparse
import sys
import os
import collections

# Constants
DEFAULT_ROLE = 'default'
CREDENTIALS_FILE = "{}/.aws/credentials".format(os.path.expanduser("~"))
CREDENTIALS_BACKUP = CREDENTIALS_FILE + ".aws_save"


class AWSCredentials:
    """
    Class to process AWS credential files to set default roles/region.
    """

    def __init__(self):
        """
        Class constructor
        """
        self.creds = configparser.ConfigParser()
        try:
            # Check for credential file or a backup.
            if not os.path.exists(CREDENTIALS_FILE):
                # Search for a backup (maybe it was previously renamed?)
                if os.path.exists(CREDENTIALS_BACKUP):
                    os.rename(CREDENTIALS_BACKUP, CREDENTIALS_FILE)
                else:
                    raise FileNotFoundError("AWS credentials: {} not found.".format(CREDENTIALS_FILE))
            self.creds.read(CREDENTIALS_FILE)

        except Exception as e:
            sys.stderr.write("Error: {}\n".format(e))
            exit(1)
        self.roles = self.creds.sections()
        self.default_role = None

    def export_role(self, role):
        """
        Print export lines to the console.
        Args:
            role: AWS role to print

        Returns:
            None
        """
        for (key_var, key_val) in self.creds.items(role):
            key_var = "export {}".format(key_var.upper())
            print("{}=\'{}\'".format(key_var, key_val))

        # Disable credentials file by renaming it.
        os.rename(CREDENTIALS_FILE, CREDENTIALS_BACKUP)

        print("# {} was moved to {} as a backup.".format(CREDENTIALS_FILE, CREDENTIALS_BACKUP))

    def set_default_role(self, role, region, export=False):
        """
        Sets the default role in the credentials file.
        Args:
            role: AWS role to set.
            region: AWS region to set.
            export: True to print export lines and rename credentials, False otherwise.
        Returns:
            None
        """
        if DEFAULT_ROLE not in self.roles:
            self.creds.add_section(DEFAULT_ROLE)
        self.default_role = role

        # Set order of credentials config
        self.creds._sections = collections.OrderedDict(sorted(self.creds._sections.items(), key=lambda t: t[0]))

        for (key_var, key_val) in self.creds.items(role):
            self.creds.set(DEFAULT_ROLE, key_var, key_val)

        self.creds.set(DEFAULT_ROLE, 'AWS_DEFAULT_REGION', region)
        self.creds.set(DEFAULT_ROLE, 'REGION', region)

        # Re-write the credentials file
        with open(CREDENTIALS_FILE, 'w') as configfile:
            self.creds.write(configfile)

        if not export:
            print("Default role: \'{}\' now set in {} file.".format(role, CREDENTIALS_FILE))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Process AWS credentials file.')
    parser.add_argument('-u', '--role', dest='role', type=str, required=True, action='store',
                        help='AWS user role.')
    parser.add_argument('-r', '--region', required=True, action='store',
                        help='Default AWS region. Ex: eu-west-1, us-east-2 etc.')
    parser.add_argument('-e', '--export', action='store_true', default=False,
                        help='Print export vars and backup credentials.')

    args = parser.parse_args()

    aws = AWSCredentials()
    aws.set_default_role(args.role, args.region, export=args.export)

    if args.export:
        aws.export_role(DEFAULT_ROLE)
