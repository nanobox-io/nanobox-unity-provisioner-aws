require 'json'

class Unity::IAM::Policy < Unity::IAM::Base
  
  def list(vpc)
    list = []

    # query the api
    res = manager.ListPolicies(
      'PathPrefix'  => "/Nanobox/Unity/#{vpc[:name]}/"
    )

    # extract the instance collection
    policies = res["ListPoliciesResponse"]["ListPoliciesResult"]["Policies"] rescue nil

    # short-circuit if the collection is empty
    return [] if policies.nil?

    # policies might not be a collection, but a single item
    collection = begin
      if policies['member'].is_a? Array
        policies['member']
      else
        [policies['member']]
      end
    end

    # grab the policies and process them
    collection.each do |policy|
      list << process(policy)
    end

    list
  end
  
  def show(vpc, subnet)
    list(vpc).each do |policy|
      if policy[:name] == subnet[:name]
        return policy
      end
    end
    
    # return nil if we can't find it
    nil
  end
  
  def create(vpc, subnet)
    # short-circuit if this already exists
    existing = show(vpc, subnet)
    if existing
      logger.info "IAM Policy '#{subnet[:name]}' already exists"
      return existing
    end
    
    # let's create the policy
    logger.info "Creating IAM Policy '#{subnet[:name]}'"
    res = manager.CreatePolicy(
      'Description'     => 'Auto-generated policy by Nanobox Unity.',
      'Path'            => "/Nanobox/Unity/#{vpc[:name]}/",
      'PolicyDocument'  => JSON.generate(policy_template(subnet[:id])),
      'PolicyName'      => "Nanobox-Unity-#{vpc[:name]}-#{subnet[:name]}"
    )
    
    process(res['CreatePolicyResponse']['CreatePolicyResult']['Policy'])
  end
  
  protected
  
  def process(data)
    {
      id:   data['PolicyId'],
      name: data['PolicyName'].match(/(APZ-.+)$/)[1]
    }
  end
  
  def policy_template(subnet_id)
    {
      "Version" => "2012-10-17",
      "Statement" => [
        {
          "Effect" => 'Deny',
          "Action" => [
            'ec2:RunInstances',
            'ec2:RebootInstances',
            'ec2:TerminateInstances'
          ],
          "Resource" => [
            "arn:aws:ec2:*:*:network-interface/*"
          ],
          "Condition" => {
            "ArnNotEquals" => {
              "ec2:Subnet" => "arn:aws:ec2:*:*:subnet/#{subnet_id}"
            }
          }
        },
        {
          "Effect" => 'Allow',
          "Action" => [
            'ec2:CreateTags',
            'ec2:RebootInstances',
            'ec2:RunInstances',
            'ec2:TerminateInstances',
            'ec2:DescribeAvailabilityZones',
            'ec2:DescribeInstances',
            'ec2:DescribeKeyPairs',
            'ec2:DescribeSecurityGroups',
            'ec2:DescribeSubnets',
            'ec2:DescribeVpcs',
            'ec2:ImportKeyPair',
            'ec2:DeleteKeyPair'
          ],
          "Resource" => [
            "arn:aws:ec2:*:*:image/*",
            "arn:aws:ec2:*:*:instance/*",
            "arn:aws:ec2:*:*:network-interface/*",
            "arn:aws:ec2:*:*:security-group/*",
            "arn:aws:ec2:*:*:subnet/#{subnet_id}",
            "arn:aws:ec2:*:*:volume/*",
          ]
        }
      ]
    }
  end
  
end
