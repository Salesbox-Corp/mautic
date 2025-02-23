import boto3
import json

def get_client_versions():
    client = boto3.client('ecs')
    versions = {}
    
    clusters = client.list_clusters()
    for cluster in clusters['clusterArns']:
        services = client.list_services(cluster=cluster)
        for service in services['serviceArns']:
            task_def = client.describe_task_definition(
                taskDefinition=service['taskDefinitionArn']
            )
            versions[service['name']] = task_def['version']
    
    return versions 