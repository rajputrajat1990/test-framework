#!/usr/bin/env python3
"""
Sprint 5: Deployment Health Check System
Comprehensive health validation for production deployments
"""

import json
import argparse
import sys
import time
import logging
import requests
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple
from confluent_kafka.admin import AdminClient, ConfigResource, ConfigSource
from confluent_kafka import Producer, Consumer, KafkaException
import subprocess

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class DeploymentHealthChecker:
    """Comprehensive deployment health validation"""
    
    def __init__(self, environment: str, cluster_id: str):
        self.environment = environment
        self.cluster_id = cluster_id
        self.health_results = []
        
        # Initialize Kafka admin client
        self.admin_config = {
            'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS'),
            'security.protocol': 'SASL_SSL',
            'sasl.mechanism': 'PLAIN',
            'sasl.username': os.getenv('CONFLUENT_CLOUD_API_KEY'),
            'sasl.password': os.getenv('CONFLUENT_CLOUD_API_SECRET')
        }
        
        try:
            self.admin_client = AdminClient(self.admin_config)
            logger.info("Kafka admin client initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize Kafka admin client: {e}")
            raise
    
    def run_health_checks(self, expected_topics: int, expected_connectors: int, timeout: int = 300) -> Dict:
        """Run comprehensive health checks"""
        logger.info(f"Starting health checks for environment: {self.environment}")
        
        start_time = datetime.now()
        health_summary = {
            'environment': self.environment,
            'cluster_id': self.cluster_id,
            'timestamp': start_time.isoformat(),
            'checks': [],
            'overall_status': 'UNKNOWN',
            'execution_time_seconds': 0
        }
        
        try:
            # 1. Cluster connectivity check
            connectivity_result = self._check_cluster_connectivity()
            health_summary['checks'].append(connectivity_result)
            
            # 2. Topic validation
            topics_result = self._check_topics(expected_topics)
            health_summary['checks'].append(topics_result)
            
            # 3. Connector validation
            connectors_result = self._check_connectors(expected_connectors)
            health_summary['checks'].append(connectors_result)
            
            # 4. Schema Registry health
            schema_registry_result = self._check_schema_registry()
            health_summary['checks'].append(schema_registry_result)
            
            # 5. Monitoring integration health
            monitoring_result = self._check_monitoring_integration()
            health_summary['checks'].append(monitoring_result)
            
            # 6. Security configuration validation
            security_result = self._check_security_configuration()
            health_summary['checks'].append(security_result)
            
            # 7. Performance baseline validation
            performance_result = self._check_performance_baseline()
            health_summary['checks'].append(performance_result)
            
            # 8. Data flow end-to-end test
            e2e_result = self._check_end_to_end_flow()
            health_summary['checks'].append(e2e_result)
            
            # Calculate overall status
            failed_checks = [c for c in health_summary['checks'] if c['status'] != 'PASS']
            critical_failures = [c for c in failed_checks if c.get('critical', False)]
            
            if critical_failures:
                health_summary['overall_status'] = 'CRITICAL'
            elif failed_checks:
                health_summary['overall_status'] = 'WARNING'
            else:
                health_summary['overall_status'] = 'HEALTHY'
            
        except Exception as e:
            logger.error(f"Health check execution failed: {e}")
            health_summary['checks'].append({
                'name': 'health_check_execution',
                'status': 'FAIL',
                'message': f'Health check execution failed: {str(e)}',
                'critical': True
            })
            health_summary['overall_status'] = 'CRITICAL'
        
        finally:
            end_time = datetime.now()
            health_summary['execution_time_seconds'] = (end_time - start_time).total_seconds()
        
        return health_summary
    
    def _check_cluster_connectivity(self) -> Dict:
        """Check basic cluster connectivity"""
        logger.info("Checking cluster connectivity...")
        
        try:
            # List topics to verify connectivity
            metadata = self.admin_client.list_topics(timeout=10)
            
            return {
                'name': 'cluster_connectivity',
                'status': 'PASS',
                'message': f'Successfully connected to cluster {self.cluster_id}',
                'details': {
                    'cluster_id': metadata.cluster_id,
                    'broker_count': len(metadata.brokers),
                    'topic_count': len(metadata.topics)
                },
                'critical': True
            }
        except Exception as e:
            return {
                'name': 'cluster_connectivity',
                'status': 'FAIL',
                'message': f'Failed to connect to cluster: {str(e)}',
                'critical': True
            }
    
    def _check_topics(self, expected_count: int) -> Dict:
        """Validate topic configuration and availability"""
        logger.info(f"Checking topics (expecting {expected_count})...")
        
        try:
            metadata = self.admin_client.list_topics(timeout=10)
            actual_count = len(metadata.topics)
            
            # Check for environment-specific topics
            env_topics = [t for t in metadata.topics.keys() if t.startswith(self.environment)]
            
            status = 'PASS' if actual_count >= expected_count else 'FAIL'
            
            # Additional topic health checks
            topic_details = []
            for topic_name, topic_metadata in list(metadata.topics.items())[:5]:  # Check first 5 topics
                partition_count = len(topic_metadata.partitions)
                topic_details.append({
                    'name': topic_name,
                    'partitions': partition_count,
                    'leader_available': all(p.leader != -1 for p in topic_metadata.partitions.values())
                })
            
            return {
                'name': 'topics_validation',
                'status': status,
                'message': f'Found {actual_count} topics (expected: {expected_count})',
                'details': {
                    'total_topics': actual_count,
                    'environment_topics': len(env_topics),
                    'expected_count': expected_count,
                    'sample_topics': topic_details
                },
                'critical': False
            }
            
        except Exception as e:
            return {
                'name': 'topics_validation',
                'status': 'FAIL',
                'message': f'Failed to validate topics: {str(e)}',
                'critical': False
            }
    
    def _check_connectors(self, expected_count: int) -> Dict:
        """Check connector status and health"""
        logger.info(f"Checking connectors (expecting {expected_count})...")
        
        try:
            # Use Confluent Cloud API to check connectors
            api_response = self._call_confluent_api(f'/connect/v1/environments/{os.getenv("CONFLUENT_ENVIRONMENT_ID")}/clusters/{self.cluster_id}/connectors')
            
            if api_response and 'error' not in api_response:
                connector_count = len(api_response)
                
                # Check connector status
                connector_details = []
                for connector_name in api_response[:3]:  # Check first 3 connectors
                    status_response = self._call_confluent_api(
                        f'/connect/v1/environments/{os.getenv("CONFLUENT_ENVIRONMENT_ID")}/clusters/{self.cluster_id}/connectors/{connector_name}/status'
                    )
                    if status_response:
                        connector_details.append({
                            'name': connector_name,
                            'status': status_response.get('connector', {}).get('state', 'UNKNOWN'),
                            'tasks': len(status_response.get('tasks', []))
                        })
                
                status = 'PASS' if connector_count >= expected_count else 'WARN'
                
                return {
                    'name': 'connectors_validation',
                    'status': status,
                    'message': f'Found {connector_count} connectors (expected: {expected_count})',
                    'details': {
                        'total_connectors': connector_count,
                        'expected_count': expected_count,
                        'sample_connectors': connector_details
                    },
                    'critical': False
                }
            else:
                return {
                    'name': 'connectors_validation',
                    'status': 'FAIL',
                    'message': 'Failed to retrieve connector information',
                    'critical': False
                }
                
        except Exception as e:
            return {
                'name': 'connectors_validation',
                'status': 'FAIL',
                'message': f'Failed to check connectors: {str(e)}',
                'critical': False
            }
    
    def _check_schema_registry(self) -> Dict:
        """Check Schema Registry health"""
        logger.info("Checking Schema Registry...")
        
        try:
            schema_registry_url = os.getenv('SCHEMA_REGISTRY_URL')
            if not schema_registry_url:
                return {
                    'name': 'schema_registry_health',
                    'status': 'SKIP',
                    'message': 'Schema Registry URL not configured',
                    'critical': False
                }
            
            # Check Schema Registry health endpoint
            response = requests.get(f'{schema_registry_url}/subjects', timeout=10)
            
            if response.status_code == 200:
                subjects = response.json()
                return {
                    'name': 'schema_registry_health',
                    'status': 'PASS',
                    'message': f'Schema Registry is healthy with {len(subjects)} subjects',
                    'details': {
                        'subject_count': len(subjects),
                        'subjects': subjects[:5]  # First 5 subjects
                    },
                    'critical': False
                }
            else:
                return {
                    'name': 'schema_registry_health',
                    'status': 'FAIL',
                    'message': f'Schema Registry returned status {response.status_code}',
                    'critical': False
                }
                
        except Exception as e:
            return {
                'name': 'schema_registry_health',
                'status': 'FAIL',
                'message': f'Schema Registry health check failed: {str(e)}',
                'critical': False
            }
    
    def _check_monitoring_integration(self) -> Dict:
        """Check monitoring and observability integration"""
        logger.info("Checking monitoring integration...")
        
        try:
            # Check if monitoring topics exist
            metadata = self.admin_client.list_topics(timeout=10)
            monitoring_topics = [t for t in metadata.topics.keys() if 'monitoring' in t or 'metrics' in t or 'logs' in t]
            
            # Check Sumo Logic connectivity if configured
            sumo_endpoint = os.getenv('SUMO_LOGIC_ENDPOINT')
            sumo_healthy = False
            
            if sumo_endpoint:
                try:
                    test_log = {'test': True, 'timestamp': datetime.now().isoformat(), 'source': 'health_check'}
                    response = requests.post(sumo_endpoint, json=test_log, timeout=5)
                    sumo_healthy = response.status_code == 200
                except:
                    pass
            
            status = 'PASS' if (len(monitoring_topics) > 0 and (not sumo_endpoint or sumo_healthy)) else 'WARN'
            
            return {
                'name': 'monitoring_integration',
                'status': status,
                'message': f'Monitoring integration status: {len(monitoring_topics)} topics, Sumo Logic: {"OK" if sumo_healthy else "N/A"}',
                'details': {
                    'monitoring_topics': len(monitoring_topics),
                    'sumo_logic_configured': bool(sumo_endpoint),
                    'sumo_logic_healthy': sumo_healthy,
                    'topic_names': monitoring_topics
                },
                'critical': False
            }
            
        except Exception as e:
            return {
                'name': 'monitoring_integration',
                'status': 'FAIL',
                'message': f'Monitoring integration check failed: {str(e)}',
                'critical': False
            }
    
    def _check_security_configuration(self) -> Dict:
        """Validate security configuration"""
        logger.info("Checking security configuration...")
        
        try:
            # Check if security topics exist
            metadata = self.admin_client.list_topics(timeout=10)
            security_topics = [t for t in metadata.topics.keys() if 'audit' in t or 'security' in t]
            
            # Verify TLS is enforced (connection should be secure)
            tls_enabled = 'SASL_SSL' in str(self.admin_config.get('security.protocol', ''))
            
            # Check for proper authentication
            auth_configured = bool(self.admin_config.get('sasl.username') and self.admin_config.get('sasl.password'))
            
            status = 'PASS' if (tls_enabled and auth_configured) else 'FAIL'
            
            return {
                'name': 'security_configuration',
                'status': status,
                'message': f'Security validation: TLS={tls_enabled}, Auth={auth_configured}, Audit topics={len(security_topics)}',
                'details': {
                    'tls_enabled': tls_enabled,
                    'authentication_configured': auth_configured,
                    'security_topics_count': len(security_topics),
                    'security_topics': security_topics
                },
                'critical': True
            }
            
        except Exception as e:
            return {
                'name': 'security_configuration',
                'status': 'FAIL',
                'message': f'Security configuration check failed: {str(e)}',
                'critical': True
            }
    
    def _check_performance_baseline(self) -> Dict:
        """Check basic performance metrics"""
        logger.info("Checking performance baseline...")
        
        try:
            # Simple latency test - measure list_topics response time
            start_time = time.time()
            metadata = self.admin_client.list_topics(timeout=10)
            latency = (time.time() - start_time) * 1000  # Convert to milliseconds
            
            # Performance thresholds (adjust based on environment)
            max_latency_ms = 5000 if self.environment == 'prod' else 10000
            
            status = 'PASS' if latency < max_latency_ms else 'WARN'
            
            return {
                'name': 'performance_baseline',
                'status': status,
                'message': f'API latency: {latency:.2f}ms (threshold: {max_latency_ms}ms)',
                'details': {
                    'api_latency_ms': round(latency, 2),
                    'threshold_ms': max_latency_ms,
                    'broker_count': len(metadata.brokers),
                    'topic_count': len(metadata.topics)
                },
                'critical': False
            }
            
        except Exception as e:
            return {
                'name': 'performance_baseline',
                'status': 'FAIL',
                'message': f'Performance baseline check failed: {str(e)}',
                'critical': False
            }
    
    def _check_end_to_end_flow(self) -> Dict:
        """Test end-to-end data flow"""
        logger.info("Running end-to-end flow test...")
        
        try:
            test_topic = f"{self.environment}-health-check-{int(time.time())}"
            
            # Create test topic
            from confluent_kafka.admin import NewTopic
            new_topic = NewTopic(test_topic, num_partitions=1, replication_factor=2)
            futures = self.admin_client.create_topics([new_topic])
            
            # Wait for topic creation
            for topic, future in futures.items():
                try:
                    future.result(timeout=30)
                    logger.info(f"Test topic {test_topic} created")
                except Exception as e:
                    logger.error(f"Failed to create test topic: {e}")
                    raise
            
            # Test producer
            producer_config = self.admin_config.copy()
            producer = Producer(producer_config)
            
            test_message = {
                'test_id': f'health_check_{int(time.time())}',
                'timestamp': datetime.now().isoformat(),
                'environment': self.environment
            }
            
            producer.produce(test_topic, json.dumps(test_message).encode('utf-8'))
            producer.flush(timeout=30)
            
            # Test consumer
            consumer_config = self.admin_config.copy()
            consumer_config.update({
                'group.id': f'{self.environment}-health-check-consumer',
                'auto.offset.reset': 'earliest',
                'enable.auto.commit': False
            })
            
            consumer = Consumer(consumer_config)
            consumer.subscribe([test_topic])
            
            message_received = False
            for _ in range(10):  # Try for 10 seconds
                msg = consumer.poll(timeout=1.0)
                if msg is not None and not msg.error():
                    received_data = json.loads(msg.value().decode('utf-8'))
                    if received_data.get('test_id') == test_message['test_id']:
                        message_received = True
                        break
            
            consumer.close()
            
            # Clean up test topic
            self.admin_client.delete_topics([test_topic])
            
            status = 'PASS' if message_received else 'FAIL'
            
            return {
                'name': 'end_to_end_flow',
                'status': status,
                'message': f'End-to-end test: {"SUCCESS" if message_received else "FAILED"}',
                'details': {
                    'test_topic': test_topic,
                    'message_produced': True,
                    'message_consumed': message_received,
                    'test_duration_seconds': 10
                },
                'critical': True
            }
            
        except Exception as e:
            return {
                'name': 'end_to_end_flow',
                'status': 'FAIL',
                'message': f'End-to-end test failed: {str(e)}',
                'critical': True
            }
    
    def _call_confluent_api(self, endpoint: str) -> Optional[Dict]:
        """Make API call to Confluent Cloud REST API"""
        try:
            base_url = "https://api.confluent.cloud"
            url = f"{base_url}{endpoint}"
            
            headers = {
                'Authorization': f'Basic {self._get_auth_header()}',
                'Content-Type': 'application/json'
            }
            
            response = requests.get(url, headers=headers, timeout=30)
            
            if response.status_code == 200:
                return response.json()
            else:
                logger.error(f"API call failed: {response.status_code} - {response.text}")
                return {'error': f"HTTP {response.status_code}"}
                
        except Exception as e:
            logger.error(f"API call exception: {e}")
            return {'error': str(e)}
    
    def _get_auth_header(self) -> str:
        """Get base64 encoded auth header for Confluent Cloud API"""
        import base64
        
        api_key = os.getenv('CONFLUENT_CLOUD_API_KEY')
        api_secret = os.getenv('CONFLUENT_CLOUD_API_SECRET')
        
        if not api_key or not api_secret:
            raise ValueError("Confluent Cloud API credentials not found")
        
        credentials = f"{api_key}:{api_secret}"
        return base64.b64encode(credentials.encode()).decode()

def main():
    parser = argparse.ArgumentParser(description='Run deployment health checks')
    parser.add_argument('--environment', required=True, help='Environment name')
    parser.add_argument('--cluster-id', required=True, help='Kafka cluster ID')
    parser.add_argument('--expected-topics', type=int, default=5, help='Expected number of topics')
    parser.add_argument('--expected-connectors', type=int, default=0, help='Expected number of connectors')
    parser.add_argument('--health-check-timeout', type=int, default=300, help='Health check timeout in seconds')
    parser.add_argument('--output', default='health-check-report.json', help='Output report file')
    
    args = parser.parse_args()
    
    # Initialize health checker
    checker = DeploymentHealthChecker(args.environment, args.cluster_id)
    
    # Run health checks
    results = checker.run_health_checks(args.expected_topics, args.expected_connectors, args.health_check_timeout)
    
    # Write results to file
    with open(args.output, 'w') as f:
        json.dump(results, f, indent=2)
    
    # Print summary
    print(f"\nHealth Check Summary for {args.environment}:")
    print(f"Overall Status: {results['overall_status']}")
    print(f"Total Checks: {len(results['checks'])}")
    
    passed_checks = [c for c in results['checks'] if c['status'] == 'PASS']
    failed_checks = [c for c in results['checks'] if c['status'] == 'FAIL']
    warning_checks = [c for c in results['checks'] if c['status'] in ['WARN', 'WARNING']]
    
    print(f"Passed: {len(passed_checks)}")
    print(f"Failed: {len(failed_checks)}")
    print(f"Warnings: {len(warning_checks)}")
    print(f"Execution Time: {results['execution_time_seconds']:.2f} seconds")
    
    if failed_checks:
        print(f"\nFailed Checks:")
        for check in failed_checks:
            print(f"  - {check['name']}: {check['message']}")
    
    print(f"\nDetailed report saved to: {args.output}")
    
    # Exit with appropriate code
    if results['overall_status'] == 'CRITICAL':
        sys.exit(2)
    elif results['overall_status'] == 'WARNING':
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == '__main__':
    main()
