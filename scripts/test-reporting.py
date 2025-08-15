#!/usr/bin/env python3
"""
Sprint 5: Advanced Test Execution Reporting System
Comprehensive test result analysis, reporting, and insights generation
"""

import json
import yaml
import sqlite3
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, asdict
from jinja2 import Template
import xml.etree.ElementTree as ET
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, Image
from reportlab.lib import colors
import argparse
import logging
import sys
import os

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class TestResult:
    """Test execution result data structure"""
    test_name: str
    test_suite: str
    status: str  # PASSED, FAILED, SKIPPED
    duration: float
    timestamp: datetime
    error_message: Optional[str] = None
    error_type: Optional[str] = None
    test_file: Optional[str] = None
    environment: Optional[str] = None
    component: Optional[str] = None

@dataclass
class TestSuiteResult:
    """Test suite execution summary"""
    suite_name: str
    total_tests: int
    passed_tests: int
    failed_tests: int
    skipped_tests: int
    duration: float
    success_rate: float
    timestamp: datetime
    environment: str

@dataclass
class ExecutionSummary:
    """Overall test execution summary"""
    total_tests: int
    total_suites: int
    passed_tests: int
    failed_tests: int
    skipped_tests: int
    total_duration: float
    overall_success_rate: float
    start_time: datetime
    end_time: datetime
    environment: str
    pipeline_id: Optional[str] = None
    commit_sha: Optional[str] = None

class TestDataManager:
    """Manages test data storage and retrieval"""
    
    def __init__(self, db_path: str = "test_results.db"):
        self.db_path = db_path
        self.init_database()
    
    def init_database(self):
        """Initialize SQLite database for test results"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Test results table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS test_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                test_name TEXT NOT NULL,
                test_suite TEXT NOT NULL,
                status TEXT NOT NULL,
                duration REAL NOT NULL,
                timestamp TEXT NOT NULL,
                error_message TEXT,
                error_type TEXT,
                test_file TEXT,
                environment TEXT,
                component TEXT
            )
        """)
        
        # Test suite results table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS suite_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                suite_name TEXT NOT NULL,
                total_tests INTEGER NOT NULL,
                passed_tests INTEGER NOT NULL,
                failed_tests INTEGER NOT NULL,
                skipped_tests INTEGER NOT NULL,
                duration REAL NOT NULL,
                success_rate REAL NOT NULL,
                timestamp TEXT NOT NULL,
                environment TEXT NOT NULL
            )
        """)
        
        # Execution summary table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS execution_summary (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                total_tests INTEGER NOT NULL,
                total_suites INTEGER NOT NULL,
                passed_tests INTEGER NOT NULL,
                failed_tests INTEGER NOT NULL,
                skipped_tests INTEGER NOT NULL,
                total_duration REAL NOT NULL,
                overall_success_rate REAL NOT NULL,
                start_time TEXT NOT NULL,
                end_time TEXT NOT NULL,
                environment TEXT NOT NULL,
                pipeline_id TEXT,
                commit_sha TEXT
            )
        """)
        
        conn.commit()
        conn.close()
        logger.info(f"Database initialized: {self.db_path}")
    
    def store_test_result(self, result: TestResult):
        """Store a test result in the database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            INSERT INTO test_results 
            (test_name, test_suite, status, duration, timestamp, error_message, 
             error_type, test_file, environment, component)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            result.test_name, result.test_suite, result.status, result.duration,
            result.timestamp.isoformat(), result.error_message, result.error_type,
            result.test_file, result.environment, result.component
        ))
        
        conn.commit()
        conn.close()
    
    def get_recent_results(self, days: int = 30) -> List[TestResult]:
        """Get test results from the last N days"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        since_date = (datetime.now() - timedelta(days=days)).isoformat()
        cursor.execute("""
            SELECT * FROM test_results 
            WHERE timestamp > ? 
            ORDER BY timestamp DESC
        """, (since_date,))
        
        results = []
        for row in cursor.fetchall():
            results.append(TestResult(
                test_name=row[1], test_suite=row[2], status=row[3], 
                duration=row[4], timestamp=datetime.fromisoformat(row[5]),
                error_message=row[6], error_type=row[7], test_file=row[8],
                environment=row[9], component=row[10]
            ))
        
        conn.close()
        return results

class JUnitParser:
    """Parse JUnit XML test results"""
    
    @staticmethod
    def parse_junit_file(file_path: str) -> Tuple[List[TestResult], TestSuiteResult]:
        """Parse JUnit XML file and extract test results"""
        tree = ET.parse(file_path)
        root = tree.getroot()
        
        results = []
        
        # Handle both <testsuite> and <testsuites> root elements
        testsuites = root.findall('.//testsuite')
        if not testsuites:
            testsuites = [root] if root.tag == 'testsuite' else []
        
        suite_results = []
        
        for testsuite in testsuites:
            suite_name = testsuite.get('name', 'Unknown Suite')
            suite_timestamp = datetime.now()  # Default to now if not provided
            
            if testsuite.get('timestamp'):
                try:
                    suite_timestamp = datetime.fromisoformat(testsuite.get('timestamp').replace('Z', '+00:00'))
                except:
                    pass
            
            total_tests = int(testsuite.get('tests', 0))
            failures = int(testsuite.get('failures', 0))
            errors = int(testsuite.get('errors', 0))
            skipped = int(testsuite.get('skipped', 0))
            duration = float(testsuite.get('time', 0))
            
            passed_tests = total_tests - failures - errors - skipped
            success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
            
            suite_result = TestSuiteResult(
                suite_name=suite_name,
                total_tests=total_tests,
                passed_tests=passed_tests,
                failed_tests=failures + errors,
                skipped_tests=skipped,
                duration=duration,
                success_rate=success_rate,
                timestamp=suite_timestamp,
                environment=os.getenv('ENVIRONMENT', 'unknown')
            )
            suite_results.append(suite_result)
            
            # Parse individual test cases
            for testcase in testsuite.findall('testcase'):
                test_name = testcase.get('name')
                classname = testcase.get('classname', suite_name)
                test_duration = float(testcase.get('time', 0))
                
                # Determine test status
                failure = testcase.find('failure')
                error = testcase.find('error')
                skipped = testcase.find('skipped')
                
                if failure is not None:
                    status = 'FAILED'
                    error_message = failure.text or failure.get('message')
                    error_type = failure.get('type', 'Failure')
                elif error is not None:
                    status = 'FAILED'
                    error_message = error.text or error.get('message')
                    error_type = error.get('type', 'Error')
                elif skipped is not None:
                    status = 'SKIPPED'
                    error_message = skipped.text or skipped.get('message')
                    error_type = 'Skipped'
                else:
                    status = 'PASSED'
                    error_message = None
                    error_type = None
                
                result = TestResult(
                    test_name=test_name,
                    test_suite=suite_name,
                    status=status,
                    duration=test_duration,
                    timestamp=suite_timestamp,
                    error_message=error_message,
                    error_type=error_type,
                    test_file=classname,
                    environment=os.getenv('ENVIRONMENT', 'unknown')
                )
                results.append(result)
        
        return results, suite_results

class TestAnalytics:
    """Advanced test analytics and insights"""
    
    def __init__(self, data_manager: TestDataManager):
        self.data_manager = data_manager
    
    def calculate_trend_analysis(self, days: int = 30) -> Dict:
        """Calculate test execution trends"""
        results = self.data_manager.get_recent_results(days)
        
        if not results:
            return {"error": "No test results found"}
        
        # Group results by date
        daily_stats = {}
        for result in results:
            date_key = result.timestamp.date()
            if date_key not in daily_stats:
                daily_stats[date_key] = {'total': 0, 'passed': 0, 'failed': 0, 'duration': 0}
            
            daily_stats[date_key]['total'] += 1
            if result.status == 'PASSED':
                daily_stats[date_key]['passed'] += 1
            elif result.status == 'FAILED':
                daily_stats[date_key]['failed'] += 1
            daily_stats[date_key]['duration'] += result.duration
        
        # Calculate trends
        dates = sorted(daily_stats.keys())
        success_rates = []
        avg_durations = []
        
        for date in dates:
            stats = daily_stats[date]
            success_rate = (stats['passed'] / stats['total'] * 100) if stats['total'] > 0 else 0
            avg_duration = stats['duration'] / stats['total'] if stats['total'] > 0 else 0
            success_rates.append(success_rate)
            avg_durations.append(avg_duration)
        
        # Calculate linear regression for trends
        if len(success_rates) > 1:
            x_values = list(range(len(success_rates)))
            success_trend = self._calculate_linear_trend(x_values, success_rates)
            duration_trend = self._calculate_linear_trend(x_values, avg_durations)
        else:
            success_trend = 0
            duration_trend = 0
        
        return {
            "daily_stats": daily_stats,
            "success_rate_trend": success_trend,
            "duration_trend": duration_trend,
            "average_success_rate": sum(success_rates) / len(success_rates) if success_rates else 0,
            "average_duration": sum(avg_durations) / len(avg_durations) if avg_durations else 0
        }
    
    def identify_flaky_tests(self, days: int = 30, min_executions: int = 5) -> List[Dict]:
        """Identify tests with inconsistent results (flaky tests)"""
        results = self.data_manager.get_recent_results(days)
        
        # Group by test name
        test_stats = {}
        for result in results:
            if result.test_name not in test_stats:
                test_stats[result.test_name] = []
            test_stats[result.test_name].append(result.status)
        
        flaky_tests = []
        for test_name, statuses in test_stats.items():
            if len(statuses) >= min_executions:
                passed_count = statuses.count('PASSED')
                failed_count = statuses.count('FAILED')
                
                if passed_count > 0 and failed_count > 0:
                    flaky_score = (min(passed_count, failed_count) / len(statuses)) * 100
                    flaky_tests.append({
                        'test_name': test_name,
                        'total_executions': len(statuses),
                        'passed_count': passed_count,
                        'failed_count': failed_count,
                        'flaky_score': flaky_score
                    })
        
        return sorted(flaky_tests, key=lambda x: x['flaky_score'], reverse=True)
    
    def analyze_failure_patterns(self, days: int = 30) -> Dict:
        """Analyze failure patterns and categorize errors"""
        results = self.data_manager.get_recent_results(days)
        failed_results = [r for r in results if r.status == 'FAILED']
        
        # Group by error type
        error_types = {}
        for result in failed_results:
            error_type = result.error_type or 'Unknown'
            if error_type not in error_types:
                error_types[error_type] = []
            error_types[error_type].append(result)
        
        # Group by component
        component_failures = {}
        for result in failed_results:
            component = result.component or 'Unknown'
            if component not in component_failures:
                component_failures[component] = 0
            component_failures[component] += 1
        
        return {
            "total_failures": len(failed_results),
            "error_type_distribution": {k: len(v) for k, v in error_types.items()},
            "component_failure_distribution": component_failures,
            "top_failing_tests": self._get_top_failing_tests(failed_results)
        }
    
    def _calculate_linear_trend(self, x_values: List[int], y_values: List[float]) -> float:
        """Calculate linear trend (slope) for a series of values"""
        n = len(x_values)
        if n < 2:
            return 0
        
        sum_x = sum(x_values)
        sum_y = sum(y_values)
        sum_xy = sum(x * y for x, y in zip(x_values, y_values))
        sum_x2 = sum(x * x for x in x_values)
        
        slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
        return slope
    
    def _get_top_failing_tests(self, failed_results: List[TestResult], limit: int = 10) -> List[Dict]:
        """Get the tests that fail most frequently"""
        test_failures = {}
        for result in failed_results:
            test_name = result.test_name
            if test_name not in test_failures:
                test_failures[test_name] = {'count': 0, 'latest_error': ''}
            test_failures[test_name]['count'] += 1
            test_failures[test_name]['latest_error'] = result.error_message or ''
        
        sorted_failures = sorted(test_failures.items(), key=lambda x: x[1]['count'], reverse=True)
        return [
            {'test_name': test, 'failure_count': data['count'], 'latest_error': data['latest_error']}
            for test, data in sorted_failures[:limit]
        ]

class ReportGenerator:
    """Generate comprehensive test reports in multiple formats"""
    
    def __init__(self, data_manager: TestDataManager, analytics: TestAnalytics):
        self.data_manager = data_manager
        self.analytics = analytics
    
    def generate_html_report(self, output_path: str, days: int = 30) -> str:
        """Generate comprehensive HTML report with charts"""
        results = self.data_manager.get_recent_results(days)
        trend_analysis = self.analytics.calculate_trend_analysis(days)
        flaky_tests = self.analytics.identify_flaky_tests(days)
        failure_patterns = self.analytics.analyze_failure_patterns(days)
        
        # Create visualizations
        charts_html = self._create_visualizations(results, trend_analysis)
        
        html_template = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Test Execution Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background-color: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .summary-cards { display: flex; gap: 20px; margin: 20px 0; flex-wrap: wrap; }
        .card { background: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); flex: 1; min-width: 200px; }
        .card h3 { margin-top: 0; color: #2c3e50; }
        .success { color: #27ae60; }
        .failure { color: #e74c3c; }
        .warning { color: #f39c12; }
        .chart-container { background: white; padding: 20px; margin: 20px 0; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        .table th, .table td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        .table th { background-color: #34495e; color: white; }
        .table tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
</head>
<body>
    <div class="header">
        <h1>📊 Test Execution Report</h1>
        <p>Generated on {{ timestamp }}</p>
        <p>Environment: {{ environment }}</p>
    </div>
    
    <div class="summary-cards">
        <div class="card">
            <h3>Total Tests</h3>
            <h2 class="success">{{ total_tests }}</h2>
        </div>
        <div class="card">
            <h3>Success Rate</h3>
            <h2 class="success">{{ success_rate }}%</h2>
        </div>
        <div class="card">
            <h3>Failed Tests</h3>
            <h2 class="failure">{{ failed_tests }}</h2>
        </div>
        <div class="card">
            <h3>Average Duration</h3>
            <h2>{{ avg_duration }}s</h2>
        </div>
    </div>
    
    {{ charts_html }}
    
    <div class="chart-container">
        <h2>🔍 Test Analytics</h2>
        
        <h3>Flaky Tests ({{ flaky_count }})</h3>
        {% if flaky_tests %}
        <table class="table">
            <thead>
                <tr>
                    <th>Test Name</th>
                    <th>Executions</th>
                    <th>Passed</th>
                    <th>Failed</th>
                    <th>Flaky Score</th>
                </tr>
            </thead>
            <tbody>
                {% for test in flaky_tests[:10] %}
                <tr>
                    <td>{{ test.test_name }}</td>
                    <td>{{ test.total_executions }}</td>
                    <td class="success">{{ test.passed_count }}</td>
                    <td class="failure">{{ test.failed_count }}</td>
                    <td class="warning">{{ "%.1f" | format(test.flaky_score) }}%</td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
        {% else %}
        <p>No flaky tests detected! 🎉</p>
        {% endif %}
        
        <h3>Top Failing Tests</h3>
        {% if failure_patterns.top_failing_tests %}
        <table class="table">
            <thead>
                <tr>
                    <th>Test Name</th>
                    <th>Failure Count</th>
                    <th>Latest Error</th>
                </tr>
            </thead>
            <tbody>
                {% for test in failure_patterns.top_failing_tests %}
                <tr>
                    <td>{{ test.test_name }}</td>
                    <td class="failure">{{ test.failure_count }}</td>
                    <td style="max-width: 300px; overflow: hidden;">{{ test.latest_error[:100] }}...</td>
                </tr>
                {% endfor %}
            </tbody>
        </table>
        {% endif %}
    </div>
    
    <div class="chart-container">
        <h2>📈 Trends & Insights</h2>
        <p><strong>Success Rate Trend:</strong> 
           {% if trend_analysis.success_rate_trend > 0 %}
           <span class="success">📈 Improving (+{{ "%.2f" | format(trend_analysis.success_rate_trend) }}% per day)</span>
           {% elif trend_analysis.success_rate_trend < 0 %}
           <span class="failure">📉 Declining ({{ "%.2f" | format(trend_analysis.success_rate_trend) }}% per day)</span>
           {% else %}
           <span>📊 Stable</span>
           {% endif %}
        </p>
        <p><strong>Duration Trend:</strong>
           {% if trend_analysis.duration_trend < 0 %}
           <span class="success">⚡ Faster ({{ "%.2f" | format(-trend_analysis.duration_trend) }}s improvement per day)</span>
           {% elif trend_analysis.duration_trend > 0 %}
           <span class="warning">🐌 Slower (+{{ "%.2f" | format(trend_analysis.duration_trend) }}s per day)</span>
           {% else %}
           <span>📊 Stable</span>
           {% endif %}
        </p>
    </div>
    
    <footer style="text-align: center; margin-top: 40px; color: #7f8c8d;">
        <p>Generated by Confluent Test Framework v1.0 | Sprint 5</p>
    </footer>
</body>
</html>
        """
        
        from jinja2 import Template
        template = Template(html_template)
        
        # Calculate summary statistics
        total_tests = len(results)
        passed_tests = len([r for r in results if r.status == 'PASSED'])
        failed_tests = len([r for r in results if r.status == 'FAILED'])
        success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        avg_duration = sum(r.duration for r in results) / total_tests if total_tests > 0 else 0
        
        html_content = template.render(
            timestamp=datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            environment=os.getenv('ENVIRONMENT', 'unknown'),
            total_tests=total_tests,
            success_rate=f"{success_rate:.1f}",
            failed_tests=failed_tests,
            avg_duration=f"{avg_duration:.2f}",
            charts_html=charts_html,
            flaky_tests=flaky_tests,
            flaky_count=len(flaky_tests),
            failure_patterns=failure_patterns,
            trend_analysis=trend_analysis
        )
        
        Path(output_path).write_text(html_content, encoding='utf-8')
        logger.info(f"HTML report generated: {output_path}")
        return output_path
    
    def _create_visualizations(self, results: List[TestResult], trend_analysis: Dict) -> str:
        """Create interactive charts using Plotly"""
        charts_html = ""
        
        # Test status distribution pie chart
        if results:
            status_counts = {}
            for result in results:
                status_counts[result.status] = status_counts.get(result.status, 0) + 1
            
            fig = go.Figure(data=[go.Pie(
                labels=list(status_counts.keys()), 
                values=list(status_counts.values()),
                hole=0.3,
                marker_colors=['#27ae60', '#e74c3c', '#f39c12']
            )])
            fig.update_layout(title="Test Status Distribution", height=400)
            charts_html += f'<div class="chart-container"><div id="status-chart"></div></div>'
            charts_html += f'<script>Plotly.newPlot("status-chart", {fig.to_json()});</script>'
        
        return charts_html
    
    def generate_json_report(self, output_path: str, days: int = 30) -> str:
        """Generate machine-readable JSON report"""
        results = self.data_manager.get_recent_results(days)
        trend_analysis = self.analytics.calculate_trend_analysis(days)
        flaky_tests = self.analytics.identify_flaky_tests(days)
        failure_patterns = self.analytics.analyze_failure_patterns(days)
        
        report_data = {
            "report_metadata": {
                "generated_at": datetime.now().isoformat(),
                "environment": os.getenv('ENVIRONMENT', 'unknown'),
                "report_period_days": days,
                "framework_version": "1.0.0"
            },
            "summary": {
                "total_tests": len(results),
                "passed_tests": len([r for r in results if r.status == 'PASSED']),
                "failed_tests": len([r for r in results if r.status == 'FAILED']),
                "skipped_tests": len([r for r in results if r.status == 'SKIPPED']),
                "success_rate": (len([r for r in results if r.status == 'PASSED']) / len(results) * 100) if results else 0,
                "total_duration": sum(r.duration for r in results),
                "average_duration": sum(r.duration for r in results) / len(results) if results else 0
            },
            "trends": trend_analysis,
            "quality_insights": {
                "flaky_tests": flaky_tests,
                "failure_patterns": failure_patterns
            },
            "test_results": [asdict(result) for result in results[-100:]]  # Last 100 results
        }
        
        Path(output_path).write_text(json.dumps(report_data, indent=2, default=str), encoding='utf-8')
        logger.info(f"JSON report generated: {output_path}")
        return output_path

def main():
    """Main function to run the test reporting system"""
    parser = argparse.ArgumentParser(description='Generate comprehensive test execution reports')
    parser.add_argument('--input', '-i', help='Input JUnit XML file or directory')
    parser.add_argument('--output', '-o', default='reports', help='Output directory for reports')
    parser.add_argument('--format', '-f', choices=['html', 'json', 'all'], default='all', help='Report format')
    parser.add_argument('--days', '-d', type=int, default=30, help='Number of days to analyze')
    parser.add_argument('--db-path', default='test_results.db', help='SQLite database path')
    
    args = parser.parse_args()
    
    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(exist_ok=True)
    
    # Initialize components
    data_manager = TestDataManager(args.db_path)
    analytics = TestAnalytics(data_manager)
    generator = ReportGenerator(data_manager, analytics)
    
    # Parse input files if provided
    if args.input:
        input_path = Path(args.input)
        if input_path.is_file() and input_path.suffix == '.xml':
            logger.info(f"Parsing JUnit file: {input_path}")
            test_results, suite_results = JUnitParser.parse_junit_file(str(input_path))
            for result in test_results:
                data_manager.store_test_result(result)
        elif input_path.is_dir():
            for junit_file in input_path.glob('**/*.xml'):
                logger.info(f"Parsing JUnit file: {junit_file}")
                try:
                    test_results, suite_results = JUnitParser.parse_junit_file(str(junit_file))
                    for result in test_results:
                        data_manager.store_test_result(result)
                except Exception as e:
                    logger.error(f"Error parsing {junit_file}: {e}")
    
    # Generate reports
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    
    if args.format in ['html', 'all']:
        html_path = output_dir / f'test_report_{timestamp}.html'
        generator.generate_html_report(str(html_path), args.days)
        print(f"HTML report: {html_path}")
    
    if args.format in ['json', 'all']:
        json_path = output_dir / f'test_report_{timestamp}.json'
        generator.generate_json_report(str(json_path), args.days)
        print(f"JSON report: {json_path}")
    
    logger.info("Report generation completed!")

if __name__ == '__main__':
    main()
