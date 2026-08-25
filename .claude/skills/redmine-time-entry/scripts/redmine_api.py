#!/usr/bin/env python3
"""
Redmine REST API client script.

Reads configuration from environment variables:
- REDMINE_URL: Base URL of your Redmine instance (e.g., https://redmine.example.com)
- REDMINE_API_KEY: Your Redmine API key

Usage:
    python redmine_api.py test_connection
    python redmine_api.py fetch_projects
    python redmine_api.py fetch_issues --project-id 123
    python redmine_api.py fetch_activities
    python redmine_api.py submit_time_entry --data '{"project_id": 123, ...}'
"""

import os
import sys
import json
import argparse
import urllib.request
import urllib.error
from typing import Dict, List, Any, Optional


class RedmineAPIError(Exception):
    """Custom exception for Redmine API errors."""
    pass


class RedmineAPI:
    """Redmine REST API client."""

    def __init__(self, base_url: Optional[str] = None, api_key: Optional[str] = None):
        """
        Initialize Redmine API client.

        Args:
            base_url: Redmine base URL (defaults to REDMINE_URL env var)
            api_key: Redmine API key (defaults to REDMINE_API_KEY env var)
        """
        self.base_url = (base_url or os.getenv('REDMINE_URL', '')).rstrip('/')
        self.api_key = api_key or os.getenv('REDMINE_API_KEY', '')

        if not self.base_url:
            raise RedmineAPIError(
                "REDMINE_URL not configured. Set REDMINE_URL environment variable."
            )
        if not self.api_key:
            raise RedmineAPIError(
                "REDMINE_API_KEY not configured. Set REDMINE_API_KEY environment variable."
            )

    def _make_request(
        self,
        path: str,
        method: str = 'GET',
        data: Optional[Dict] = None,
        expected_status: int = 200
    ) -> Dict[str, Any]:
        """
        Make HTTP request to Redmine API.

        Args:
            path: API endpoint path (e.g., '/projects.json')
            method: HTTP method (GET, POST, etc.)
            data: Request body data (for POST requests)
            expected_status: Expected HTTP status code

        Returns:
            Parsed JSON response

        Raises:
            RedmineAPIError: If request fails or response is invalid
        """
        url = f"{self.base_url}{path}"

        headers = {
            'X-Redmine-API-Key': self.api_key,
            'Content-Type': 'application/json'
        }

        req_data = json.dumps(data).encode('utf-8') if data else None
        request = urllib.request.Request(url, data=req_data, headers=headers, method=method)

        try:
            with urllib.request.urlopen(request) as response:
                if response.status != expected_status:
                    raise RedmineAPIError(f"HTTP {response.status}: {response.read().decode()}")

                # Read content once
                content = response.read()

                # For 201 Created with empty body, return empty dict
                if response.status == 201 and not content:
                    return {}

                return json.loads(content.decode('utf-8'))

        except urllib.error.HTTPError as e:
            error_msg = e.read().decode('utf-8') if e.fp else str(e)
            raise RedmineAPIError(f"HTTP {e.code}: {error_msg}")
        except urllib.error.URLError as e:
            raise RedmineAPIError(f"Network error: {e.reason}")
        except json.JSONDecodeError as e:
            raise RedmineAPIError(f"Invalid JSON response: {e}")

    def test_connection(self) -> Dict[str, Any]:
        """
        Test API connection by fetching current user info.

        Returns:
            User information dict

        Example:
            {
                "user": {
                    "id": 1,
                    "login": "admin",
                    "firstname": "John",
                    "lastname": "Doe"
                }
            }
        """
        return self._make_request('/users/current.json')

    def fetch_projects(self) -> List[Dict[str, Any]]:
        """
        Fetch all accessible Redmine projects with pagination.

        Returns:
            List of project dicts (active projects only, sorted by name)

        Example:
            [
                {
                    "id": 1,
                    "name": "Project A",
                    "identifier": "project-a",
                    "status": 1
                },
                ...
            ]
        """
        all_projects = []
        offset = 0
        limit = 100

        while True:
            response = self._make_request(f'/projects.json?limit={limit}&offset={offset}')

            projects = response.get('projects', [])
            # Filter out archived projects (status == 5)
            active_projects = [p for p in projects if p.get('status') != 5]
            all_projects.extend(active_projects)

            total_count = response.get('total_count', 0)
            if offset + limit >= total_count:
                break
            offset += limit

        # Sort by name
        all_projects.sort(key=lambda p: p.get('name', ''))
        return all_projects

    def fetch_issues(self, project_id: int) -> List[Dict[str, Any]]:
        """
        Fetch issues for a specific project.

        Args:
            project_id: Redmine project ID

        Returns:
            List of issue dicts

        Example:
            [
                {
                    "id": 123,
                    "subject": "Bug fix",
                    "project": {"id": 1, "name": "Project A"},
                    "tracker": {"id": 1, "name": "Bug"},
                    "status": {"id": 1, "name": "New"}
                },
                ...
            ]
        """
        response = self._make_request(f'/issues.json?project_id={project_id}&limit=100')
        return response.get('issues', [])

    def fetch_activities(self) -> List[Dict[str, Any]]:
        """
        Fetch all time entry activity types.

        Returns:
            List of activity dicts

        Example:
            [
                {"id": 8, "name": "開発"},
                {"id": 9, "name": "テスト"},
                ...
            ]
        """
        response = self._make_request('/enumerations/time_entry_activities.json')
        return response.get('time_entry_activities', [])

    def submit_time_entry(self, time_entry: Dict[str, Any]) -> bool:
        """
        Submit a time entry to Redmine.

        Args:
            time_entry: Time entry data dict with fields:
                - project_id: int
                - issue_id: int
                - activity_id: int
                - spent_on: str (format: "yyyy-MM-dd")
                - hours: str (format: "2.5")
                - comments: str

        Returns:
            True if successful

        Example:
            submit_time_entry({
                "project_id": 123,
                "issue_id": 456,
                "activity_id": 8,
                "spent_on": "2025-01-15",
                "hours": "4.0",
                "comments": "Completed login feature"
            })
        """
        data = {"time_entry": time_entry}
        self._make_request('/time_entries.json', method='POST', data=data, expected_status=201)
        return True


def main():
    """Command-line interface for Redmine API."""
    parser = argparse.ArgumentParser(description='Redmine REST API client')
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # test_connection command
    subparsers.add_parser('test_connection', help='Test API connection')

    # fetch_projects command
    subparsers.add_parser('fetch_projects', help='Fetch all projects')

    # fetch_issues command
    issues_parser = subparsers.add_parser('fetch_issues', help='Fetch issues for a project')
    issues_parser.add_argument('--project-id', type=int, required=True, help='Project ID')

    # fetch_activities command
    subparsers.add_parser('fetch_activities', help='Fetch time entry activities')

    # submit_time_entry command
    submit_parser = subparsers.add_parser('submit_time_entry', help='Submit time entry')
    submit_parser.add_argument('--data', type=str, required=True, help='Time entry JSON data')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    try:
        api = RedmineAPI()

        if args.command == 'test_connection':
            result = api.test_connection()
            print(json.dumps(result, indent=2, ensure_ascii=False))

        elif args.command == 'fetch_projects':
            projects = api.fetch_projects()
            print(json.dumps(projects, indent=2, ensure_ascii=False))

        elif args.command == 'fetch_issues':
            issues = api.fetch_issues(args.project_id)
            print(json.dumps(issues, indent=2, ensure_ascii=False))

        elif args.command == 'fetch_activities':
            activities = api.fetch_activities()
            print(json.dumps(activities, indent=2, ensure_ascii=False))

        elif args.command == 'submit_time_entry':
            time_entry = json.loads(args.data)
            api.submit_time_entry(time_entry)
            print(json.dumps({"success": True, "message": "Time entry submitted"}, ensure_ascii=False))

        return 0

    except RedmineAPIError as e:
        print(json.dumps({"error": str(e)}, ensure_ascii=False), file=sys.stderr)
        return 1
    except Exception as e:
        print(json.dumps({"error": f"Unexpected error: {str(e)}"}, ensure_ascii=False), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
