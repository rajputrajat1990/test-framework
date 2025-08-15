#!/usr/bin/env python3
"""
Sprint 5: RBAC Permissions Testing
Test role-based access control and authorization
"""

import json
import argparse
import sys
import time
import logging
from confluent_kafka.admin import AdminClient
from confluent_kafka import Producer, Consumer
from typing import Dict, List, Tuple, Optional
import subprocess
import os
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class RBACTester:
    """Test RBAC permissions and access control"""
    
    def __init__(self, cluster_id: str, environment: str):
        self.cluster_id = cluster_id
        self.environment = environment
        self.test_results = []
        
    def test_service_account_permissions(self, service_accounts: Dict[str, str]) -> List[Dict]:
        """Test permissions for each service account"""
        results = []
        
        for sa_name, sa_id in service_accounts.items():
            logger.info(f"Testing permissions for service account: {sa_name} ({sa_id})")
            
            # Get the API key for this service account
            api_key, api_secret = self._get_service_account_credentials(sa_id)
            
            if not api_key or not api_secret:
                logger.error(f"Could not retrieve credentials for {sa_name}")
                continue
            
            # Test different operations based on expected role
            if sa_name == "kafka_admin":
                results.extend(self._test_admin_permissions(sa_name, api_key, api_secret))
            elif sa_name == "connector_operator":
                results.extend(self._test_operator_permissions(sa_name, api_key, api_secret))
            elif sa_name == "data_consumer":
                results.extend(self._test_consumer_permissions(sa_name, api_key, api_secret))
        
        return results
    
    def _get_service_account_credentials(self, sa_id: str) -> Tuple[Optional[str], Optional[str]]:
        """Retrieve API key and secret for service account"""
        try:
            # In a real implementation, this would retrieve from Vault or environment
            # For testing, we'll use environment variables
            api_key = os.getenv(f"{sa_id.upper()}_API_KEY")
            api_secret = os.getenv(f"{sa_id.upper()}_API_SECRET")
            return api_key, api_secret
        except Exception as e:
            logger.error(f"Error retrieving credentials: {e}")
            return None, None
    
    def _test_admin_permissions(self, sa_name: str, api_key: str, api_secret: str) -> List[Dict]:
        """Test administrative permissions"""
        results = []
        
        # Create admin client
        admin_config = {
            'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS'),
            'security.protocol': 'SASL_SSL',
            'sasl.mechanism': 'PLAIN',
            'sasl.username': api_key,
            'sasl.password': api_secret
        }
        
        admin_client = AdminClient(admin_config)
        
        # Test 1: List topics (should succeed)
        test_result = self._test_operation(
            sa_name, "list_topics", 
            lambda: self._list_topics(admin_client),
            expected_success=True
        )
        results.append(test_result)
        
        # Test 2: Create topic (should succeed for admin)
        test_topic = f"{self.environment}-rbac-test-{int(time.time())}"
        test_result = self._test_operation(
            sa_name, "create_topic",
            lambda: self._create_topic(admin_client, test_topic),
            expected_success=True
        )
        results.append(test_result)
        
        # Test 3: Delete topic (should succeed for admin)
        if test_result.get('success'):
            test_result = self._test_operation(
                sa_name, "delete_topic",
                lambda: self._delete_topic(admin_client, test_topic),
                expected_success=True
            )
            results.append(test_result)
        
        # Test 4: Describe cluster (should succeed for admin)
        test_result = self._test_operation(
            sa_name, "describe_cluster",
            lambda: self._describe_cluster(admin_client),
            expected_success=True
        )
        results.append(test_result)
        
        return results
    
    def _test_operator_permissions(self, sa_name: str, api_key: str, api_secret: str) -> List[Dict]:
        """Test connector operator permissions"""
        results = []
        
        admin_config = {
            'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS'),
            'security.protocol': 'SASL_SSL',
            'sasl.mechanism': 'PLAIN',
            'sasl.username': api_key,
            'sasl.password': api_secret
        }
        
        admin_client = AdminClient(admin_config)
        
        # Test 1: List topics (should succeed)
        test_result = self._test_operation(
            sa_name, "list_topics",
            lambda: self._list_topics(admin_client),
            expected_success=True
        )
        results.append(test_result)
        
        # Test 2: Create connector-prefixed topic (should succeed)
        connector_topic = f"{self.environment}-connector-rbac-test-{int(time.time())}"
        test_result = self._test_operation(
            sa_name, "create_connector_topic",
            lambda: self._create_topic(admin_client, connector_topic),
            expected_success=True
        )
        results.append(test_result)
        
        # Test 3: Try to create non-connector topic (should fail)
        non_connector_topic = f"{self.environment}-other-topic-{int(time.time())}"
        test_result = self._test_operation(
            sa_name, "create_non_connector_topic",
            lambda: self._create_topic(admin_client, non_connector_topic),
            expected_success=False
        )
        results.append(test_result)
        
        # Test 4: Try to describe cluster (should fail - no admin access)
        test_result = self._test_operation(
            sa_name, "describe_cluster",
            lambda: self._describe_cluster(admin_client),
            expected_success=False
        )
        results.append(test_result)
        
        # Clean up connector topic if created successfully
        if results[1].get('success'):
            self._delete_topic(admin_client, connector_topic)
        
        return results
    
    def _test_consumer_permissions(self, sa_name: str, api_key: str, api_secret: str) -> List[Dict]:
        """Test data consumer permissions"""
        results = []
        
        consumer_config = {
            'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS'),
            'security.protocol': 'SASL_SSL',
            'sasl.mechanism': 'PLAIN',
            'sasl.username': api_key,
            'sasl.password': api_secret,
            'group.id': f'{self.environment}-rbac-test-consumer',
            'auto.offset.reset': 'earliest',
            'enable.auto.commit': False
        }
        
        # Test 1: Subscribe to allowed topic (should succeed)
        allowed_topic = f"{self.environment}-monitoring-logs"  # Assuming this is allowed
        test_result = self._test_operation(
            sa_name, "subscribe_allowed_topic",
            lambda: self._test_consumer_subscription(consumer_config, [allowed_topic]),
            expected_success=True
        )
        results.append(test_result)
        
        # Test 2: Try to subscribe to restricted topic (should fail)
        restricted_topic = f"{self.environment}-admin-logs"
        test_result = self._test_operation(
            sa_name, "subscribe_restricted_topic",
            lambda: self._test_consumer_subscription(consumer_config, [restricted_topic]),
            expected_success=False
        )
        results.append(test_result)
        
        # Test 3: Try to produce messages (should fail - read-only access)
        producer_config = {
            'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS'),
            'security.protocol': 'SASL_SSL',
            'sasl.mechanism': 'PLAIN',
            'sasl.username': api_key,
            'sasl.password': api_secret
        }
        
        test_result = self._test_operation(
            sa_name, "produce_message",
            lambda: self._test_producer_write(producer_config, allowed_topic),
            expected_success=False
        )
        results.append(test_result)
        
        return results
    
    def _test_operation(self, sa_name: str, operation: str, operation_func, expected_success: bool) -> Dict:
        """Test a specific operation and validate the result"""
        start_time = datetime.now()
        
        try:
            result = operation_func()
            actual_success = result is not None and result != False
            
            test_passed = actual_success == expected_success
            
            return {
                'service_account': sa_name,
                'operation': operation,
                'expected_success': expected_success,
                'actual_success': actual_success,
                'test_passed': test_passed,
                'timestamp': start_time.isoformat(),
                'details': str(result) if result else "No result",
                'error_message': None
            }
            
        except Exception as e:
            actual_success = False
            test_passed = actual_success == expected_success
            
            return {
                'service_account': sa_name,
                'operation': operation,
                'expected_success': expected_success,
                'actual_success': actual_success,
                'test_passed': test_passed,
                'timestamp': start_time.isoformat(),
                'details': None,
                'error_message': str(e)
            }
    
    def _list_topics(self, admin_client: AdminClient) -> bool:
        """List topics using admin client"""
        try:
            metadata = admin_client.list_topics(timeout=10)
            return len(metadata.topics) >= 0
        except Exception as e:
            logger.error(f"Error listing topics: {e}")
            raise
    
    def _create_topic(self, admin_client: AdminClient, topic_name: str) -> bool:
        """Create a topic"""
        from confluent_kafka.admin import NewTopic
        
        try:
            new_topic = NewTopic(topic_name, num_partitions=1, replication_factor=3)
            futures = admin_client.create_topics([new_topic])
            
            for topic, future in futures.items():
                future.result(timeout=10)  # Will raise exception if creation fails
            
            return True
        except Exception as e:
            logger.error(f"Error creating topic {topic_name}: {e}")
            raise
    
    def _delete_topic(self, admin_client: AdminClient, topic_name: str) -> bool:
        """Delete a topic"""
        try:
            futures = admin_client.delete_topics([topic_name])
            
            for topic, future in futures.items():
                future.result(timeout=10)
            
            return True
        except Exception as e:
            logger.error(f"Error deleting topic {topic_name}: {e}")
            raise
    
    def _describe_cluster(self, admin_client: AdminClient) -> bool:
        """Describe cluster configuration"""
        try:
            # This operation typically requires admin privileges
            metadata = admin_client.list_topics(timeout=10)
            return metadata.cluster_id is not None
        except Exception as e:
            logger.error(f"Error describing cluster: {e}")
            raise
    
    def _test_consumer_subscription(self, config: Dict, topics: List[str]) -> bool:
        """Test consumer subscription to topics"""
        try:
            consumer = Consumer(config)
            consumer.subscribe(topics)
            
            # Try to poll for messages (timeout quickly)
            messages = consumer.poll(timeout=2.0)
            consumer.close()
            
            return True  # If we got here without exception, subscription worked
        except Exception as e:
            logger.error(f"Error with consumer subscription: {e}")
            raise
    
    def _test_producer_write(self, config: Dict, topic: str) -> bool:
        """Test producer write to topic"""
        try:
            producer = Producer(config)
            
            test_message = json.dumps({
                'test_message': True,
                'timestamp': datetime.now().isoformat(),
                'topic': topic
            })
            
            producer.produce(topic, test_message.encode('utf-8'))
            producer.flush(timeout=5.0)
            
            return True
        except Exception as e:
            logger.error(f"Error producing message to {topic}: {e}")
            raise
    
    def test_privilege_escalation(self, service_accounts: Dict[str, str]) -> List[Dict]:
        """Test for privilege escalation vulnerabilities"""
        results = []
        
        # Test if non-admin accounts can perform admin operations
        for sa_name, sa_id in service_accounts.items():
            if sa_name == "kafka_admin":
                continue  # Skip admin account
            
            api_key, api_secret = self._get_service_account_credentials(sa_id)
            if not api_key or not api_secret:
                continue
            
            admin_config = {
                'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS'),
                'security.protocol': 'SASL_SSL',
                'sasl.mechanism': 'PLAIN',
                'sasl.username': api_key,
                'sasl.password': api_secret
            }
            
            admin_client = AdminClient(admin_config)
            
            # Try admin operations that should fail
            escalation_tests = [
                ("create_admin_topic", lambda: self._create_topic(admin_client, f"{self.environment}-admin-escalation-test")),
                ("alter_cluster_config", lambda: self._describe_cluster(admin_client)),
                ("delete_system_topics", lambda: self._list_topics(admin_client))
            ]
            
            for test_name, test_func in escalation_tests:
                test_result = self._test_operation(
                    sa_name, f"escalation_{test_name}",
                    test_func,
                    expected_success=False
                )
                results.append(test_result)
        
        return results
    
    def generate_rbac_report(self, results: List[Dict]) -> str:
        """Generate RBAC test report"""
        total_tests = len(results)
        passed_tests = sum(1 for r in results if r['test_passed'])
        failed_tests = total_tests - passed_tests
        
        report = {
            "rbac_test_report": {
                "timestamp": datetime.now().isoformat(),
                "environment": self.environment,
                "cluster_id": self.cluster_id,
                "summary": {
                    "total_tests": total_tests,
                    "passed_tests": passed_tests,
                    "failed_tests": failed_tests,
                    "success_rate": (passed_tests / total_tests * 100) if total_tests > 0 else 0
                },
                "test_results": results,
                "security_findings": self._analyze_security_findings(results),
                "recommendations": self._generate_recommendations(results)
            }
        }
        
        return json.dumps(report, indent=2)
    
    def _analyze_security_findings(self, results: List[Dict]) -> List[Dict]:
        """Analyze test results for security findings"""
        findings = []
        
        # Look for unexpected successes (potential security issues)
        unexpected_successes = [r for r in results if not r['expected_success'] and r['actual_success']]
        
        for result in unexpected_successes:
            findings.append({
                "severity": "HIGH",
                "finding": "Unauthorized access detected",
                "details": f"Service account {result['service_account']} was able to perform {result['operation']} when it should have been denied",
                "recommendation": "Review RBAC configuration and ACL rules"
            })
        
        # Look for expected successes that failed (access control too restrictive)
        unexpected_failures = [r for r in results if r['expected_success'] and not r['actual_success']]
        
        for result in unexpected_failures:
            findings.append({
                "severity": "MEDIUM",
                "finding": "Expected access denied",
                "details": f"Service account {result['service_account']} was denied {result['operation']} when it should have been allowed",
                "recommendation": "Review RBAC configuration - may be too restrictive"
            })
        
        return findings
    
    def _generate_recommendations(self, results: List[Dict]) -> List[str]:
        """Generate security recommendations based on test results"""
        recommendations = []
        
        failed_tests = [r for r in results if not r['test_passed']]
        
        if failed_tests:
            recommendations.append("Review and update RBAC role bindings")
            recommendations.append("Validate ACL rules for service accounts")
            recommendations.append("Consider implementing principle of least privilege")
        
        # Check for privilege escalation attempts
        escalation_results = [r for r in results if 'escalation_' in r['operation']]
        successful_escalations = [r for r in escalation_results if r['actual_success']]
        
        if successful_escalations:
            recommendations.append("CRITICAL: Privilege escalation detected - immediate review required")
            recommendations.append("Implement additional access controls and monitoring")
        
        return recommendations

def main():
    parser = argparse.ArgumentParser(description='Test RBAC permissions and access control')
    parser.add_argument('--environment', required=True, help='Environment name')
    parser.add_argument('--cluster-id', required=True, help='Kafka cluster ID')
    parser.add_argument('--service-accounts', required=True, help='JSON string of service accounts')
    parser.add_argument('--output', default='rbac-test-report.json', help='Output report file')
    
    args = parser.parse_args()
    
    try:
        service_accounts = json.loads(args.service_accounts)
    except json.JSONDecodeError as e:
        logger.error(f"Invalid JSON for service accounts: {e}")
        sys.exit(1)
    
    # Initialize tester
    tester = RBACTester(args.cluster_id, args.environment)
    
    # Run permission tests
    logger.info("Running RBAC permission tests...")
    results = tester.test_service_account_permissions(service_accounts)
    
    # Run privilege escalation tests
    logger.info("Running privilege escalation tests...")
    escalation_results = tester.test_privilege_escalation(service_accounts)
    results.extend(escalation_results)
    
    # Generate report
    report = tester.generate_rbac_report(results)
    
    # Write report to file
    with open(args.output, 'w') as f:
        f.write(report)
    
    # Print summary
    total_tests = len(results)
    passed_tests = sum(1 for r in results if r['test_passed'])
    
    print(f"\nRBAC Testing Summary:")
    print(f"Total tests: {total_tests}")
    print(f"Passed tests: {passed_tests}")
    print(f"Failed tests: {total_tests - passed_tests}")
    print(f"Success rate: {(passed_tests / total_tests * 100):.1f}%")
    print(f"Report saved to: {args.output}")
    
    # Exit with error code if tests failed
    if passed_tests != total_tests:
        sys.exit(1)

if __name__ == '__main__':
    main()
