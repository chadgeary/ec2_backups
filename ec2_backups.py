import botocore
import boto3
import os
from time import gmtime, strftime

def lambda_handler(event, context):
  # connect
  ec2 = boto3.client("ec2")

  def deregister_previous():
    # get tag:Generation value:Previous ami(s)
    previous_amis = ec2.describe_images(
      Filters=[
        {'Name': 'tag:Generation', 'Values': [os.environ['EC2BU_TAG_GENERATION_2']]},
        {'Name': 'tag:Source', 'Values': [os.environ['EC2BU_TAG_NAME']]}
      ]
    )

    # get associated snapshots for tag:Generation value:Previous ami(s)
    # ami -> blockdevicemappings -> ebs volume -> snapshot id
    previous_snaps = []
    for ami in previous_amis['Images']:
      for key, bdms in ami.items():
        if key == 'BlockDeviceMappings':
          for bdm in bdms:
            for key, ebsvols in bdm.items():
              if key == 'Ebs':
                for key, snap in ebsvols.items():
                  if key == 'SnapshotId':
                    previous_snaps.append(snap)
    
    print('Deregistering AMIs: ')

    # deregister amis
    for previous_ami in previous_amis['Images']:
      for key, value in previous_ami.items():
        if key == 'ImageId':
          print(value)
          ami_resource = list(boto3.resource('ec2').images.filter(ImageIds=[value]).all())[0]
          ami_resource.deregister()

    print('Deleting snapshots: ')

    # delete snapshots
    for previous_snap in previous_snaps:
      print(previous_snap)
      ami_resource = list(boto3.resource('ec2').snapshots.filter(SnapshotIds=[previous_snap]).all())[0]
      ami_resource.delete()

  def rotate_current_to_previous():
    # get tag:Generation value:Current ami(s)
    current_amis = ec2.describe_images(
      Filters=[
        {'Name': 'tag:Generation', 'Values': [os.environ['EC2BU_TAG_GENERATION_1']]},
        {'Name': 'tag:Source', 'Values': [os.environ['EC2BU_TAG_NAME']]}
      ]
    )

    print('Rotating AMIs: ')

    # rotate tag:Generation value:Current ami(s) to tag:Generation value:Previous
    for current_ami in current_amis['Images']:
      for key, value in current_ami.items():
        if key == 'ImageId':
          print(value)
          ami_resource = list(boto3.resource('ec2').images.filter(ImageIds=[value]).all())[0]
          tag_response = ec2.create_tags(
            Resources=[
              ami_resource.id
            ],
            Tags=[
              {'Key': 'Generation', 'Value': os.environ['EC2BU_TAG_GENERATION_2']}
            ]
          )

  def create_amis_from_tagged():
    # get tag:Backup value:true instance(s)
    reservations = ec2.describe_instances(
      Filters=[
        {'Name': 'tag:Backup', 'Values': ['true','True']}
      ]
    )
    
    # create list of dicts (id, name tag+timestamp) for each backup instance
    backup_instances = []
    for instances in reservations['Reservations']:
      for instance in instances['Instances']:
        instance_details = {}
        instance_details['id'] = instance['InstanceId']
        for tag in instance['Tags']:
          if 'Name' in tag.values():
            instance_details['tag_name'] = tag['Value']
            instance_details['ami_name'] = tag['Value'] + '_' + strftime('%Y-%m-%d-%H%M', gmtime())
        backup_instances.append(instance_details)
    
    print('Creating AMIs from Instances: ')
    
    # create ami for each instance_id in instance_ids
    for backup_instance in backup_instances:
      ami = ec2.create_image(
        InstanceId=backup_instance['id'], Name=backup_instance['ami_name'], NoReboot=True
      )
      ec2_resource = boto3.resource('ec2')
      ami_resource = ec2_resource.Image(ami['ImageId'])
      print('Instance:',backup_instance['id'],'AMI:',ami['ImageId'])
      tag_response = ec2.create_tags(
        Resources=[
          ami['ImageId'],
        ],
        Tags=[
          {'Key': 'Name', 'Value': backup_instance['tag_name']},
          {'Key': 'Generation', 'Value': os.environ['EC2BU_TAG_GENERATION_1']},
          {'Key': 'Source', 'Value': os.environ['EC2BU_TAG_NAME']}
        ]
      )

  # perform deregister/rotate/create
  deregister_previous()
  rotate_current_to_previous()
  create_amis_from_tagged()
