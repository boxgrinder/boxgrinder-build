# BoxGrinder

BoxGrinder is a set of projects that help you grind out appliances for multiple virtualization and Cloud providers. 

Visit us at [boxgrinder.org](http://www.boxgrinder.org)

## BoxGrinder Build

BoxGrinder Build is a command line tool to help you build appliances. With an appliance definition and just a single command, BoxGrinder can create your appliance, target it to a platform and deliver it.   

### Boxgrinder Build Meta Appliance: Boxgrinder the Easy Way

The Boxgrinder Meta appliance is pre-configured with an optimal environment prepared to use Boxgrinder right from launch. Just [download the latest appliance](http://boxgrinder.org/download/boxgrinder-build-meta-appliance/) from boxgrinder.org in your desired format, launch it, and you're ready to grind out images!

It is a great way to use or test BoxGrinder in a virtual environment without affecting your local system.

Visit the [Boxgrinder Meta appliance usage article](http://boxgrinder.org/tutorials/boxgrinder-build-meta-appliance/) to learn more.

### Supported OSes

At present the project officially supports the following OSes in x86_64 and i386 variants:

* Fedora (13, 14,15)
* RHEL (5.x, 6.x) and CentOS (5.x)

### Requirements

* Acquiring and installing BoxGrinder is very simple, with RPMs ensuring the correct dependencies are pulled and installed.  However, depending upon your OS of choice, the prerequisites for installing BoxGrinder vary slightly. 
* Administrative level permissions (root or equivalent)

#### Fedora

BoxGrinder and all of its dependencies reside within the official Fedora repositories, therefore there are no special requirements. Simply install via your package manager.

#### RHEL/CentOS

EPEL and BoxGrinder repositories locations must be added to your package manager in order to install BoxGrinder and resolve its dependencies successfully.

For detailed instructions, see: [Preparing your environment](http://boxgrinder.org/tutorials/boxgrinder-build-quick-start/preparing-environment/)

### Installing

Once the prerequisites are satisfied, install BoxGrinder via a package manager, for instance in YUM;

* `sudo yum install rubygem-boxgrinder-core rubygem-boxgrinder-build ` to install BoxGrinder Core and BoxGrinder Build.

### Removing

You should remove BoxGrinder through your system package manager, for instance with YUM:

* `sudo yum remove "rubygem-boxgrinder*"`

### Usage

BoxGrinder.org's [quick-start](http://boxgrinder.org/tutorials/boxgrinder-build-quick-start/) tutorial is the best place to learn the fundamentals of BoxGrinder Build, enabling you to rapidly leverage the feature-set on offer.  

The following sections provide a basic overview of functionality. 

### Plugins

Most of the features of BoxGrinder Build are provided through plugins, with three primary variants (Operating System, Platform and Delivery), each catering for a phase of the build process.  Furthermore, the flexible and extensible structure of BoxGrinder Build enables users to seamlessly add new features and functionality.

* Operating System - provide support to run and build for a given OS
* Platform - ability to produce appliances for a specific platform, such as Amazon's EC2 or VirtualBox VM
* Delivery - send the completed appliance, for instance by SFTP or bundled as an AMI and uploaded to S3.

Learn more: [BoxGrinder Build](http://boxgrinder.org/build/)

#### Plugin Configuration

Many plugins allow, or mandate, some degree of configuration before they are executed.  These properties are aggregated into a single per-user configuration file, at `~/.boxgrinder/config`.  The user should consult the documentation of a given plugin to determine what fields it should be configured with, and which fields (if any), are requisite. 

    plugins:
      sftp:
        host: 192.168.0.1
        username: boxgrinder
        path: /home/boxgrinder/appliances

* In this example, the SFTP plugin's fields are [all mandatory](http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#SFTP_Delivery_Plugin).

Learn more: [BoxGrinder Plugins](http://boxgrinder.org/tutorials/boxgrinder-build-plugins/#Plugin_configuration) 

#### Defining Appliances

Appliances are defined in YAML, the following "JEOS" definition can be used by BoxGrinder to produce a basic, but fully functional appliance;

    name: f14-basic
    summary: Just Enough Operating System based on Fedora 14
    os:
      name: fedora
      version: 14
    hardware:
      partitions:
        "/":
          size: 2
    packages:
      - @core
  
  * With this simple definition, BoxGrinder will produce a Fedora 14 appliance with the Core [group of packages](http://yum.baseurl.org/wiki/YumGroups). You can easily add packages, repositories, and harness a plethora of powerful features in a concise, declarative manner. 
  * For an introduction to Appliance Definitions, see: [Quick-start, building your first appliance](http://boxgrinder.org/tutorials/boxgrinder-build-quick-start/build-your-first-appliance) 
  * For fuller explanations of all parameters BoxGrinder offers, see: [Appliance definition parameters](http://boxgrinder.org/tutorials/appliance-definition/)
  
#### Building Appliances
The BoxGrinder Build CLI is a simple interface through which you can instruct BoxGrinder to build your appliances. You can view a brief manual on each task by utilising the help function: 

    boxgrinder help [TASK]

BoxGrinder's primary task is `build`, and is run with a mandatory appliance definition, along with optional platform and delivery plugin specifiers.  BoxGrinder resolves the packages and associated dependencies in the appliance definition, and installs them into the new image it generates based upon the operating system and versions specified.

    boxgrinder build [appliance definition file] [options]
    
 * The two most common options are `[-p|--platform=]` and `[-d|--delivery=]`. Neither is mandatory, if platform is omitted then only the raw KVM image is created. You can can later return and target a build to different platforms, and BoxGrinder will always reuse the intermediary data where it is available. If you wish to force a rebuild, you can use the `[-f|--force]` flag.
 * It is possible to manually provide key-value pairs for platform and delivery plugin configuration on the command line. These will override any pre-existing plugin parameters set in the BoxGrinder config file.
 * Shell commands can be executed in `post` sections of the appliance definition files, which is useful for basic configuration. However, it is advisable that more complex configuration and installation of custom software is performed properly through RPM files. This is often best achieved through local repositories, which can be configured as [_ephemeral_](http://boxgrinder.org/tutorials/appliance-definition/) in order to avoid the repository being installed into the resultant image's package manager. 
 
See: [BoxGrinder Build Usage Instructions](http://boxgrinder.org/tutorials/boxgrinder-build-usage-instructions/), [How to use local repositories](http://boxgrinder.org/tutorials/how-to-use-local-repository), and `boxgrinder help build` 

##### Examples

    boxgrinder build fedora-14.appl -p vmware -d sftp

Build an image based upon _fedora-14.appl_, and produce an image targeted at the _vmware_ platform.  Once complete, deliver by _sftp_. Note that each of these plugins must be configured in `~/.boxgrinder/conf` or by providing the key-value pairs as command-line arguments.

-----------------------

    boxgrinder build fedora-14.appl -p virtualbox -d local

Assuming that BoxGrinder had succeeded in building the prior image, the RAW file is again used as an intermediary without needing to be rebuild. An image targeted at VirtualBox is then produced, and delivered to a local file, as determined in _conf_.

-----------------------

    setarch i386 boxgrinder build fedora-14.appl
    
Build an i386 appliance (on an x86_64 machine).    
