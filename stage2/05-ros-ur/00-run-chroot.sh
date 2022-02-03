#!/bin/bash -e

install_sistem_deps(){
    [ -f /etc/apt/sources.list.d/ros-latest.list ] && rm /etc/apt/sources.list.d/ros-latest.list

    sh -c """
    echo deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main \
        > /etc/apt/sources.list.d/ros-latest.list
    """
    apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' \
        --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
#
    apt-get update

    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o \
        Dpkg::Options::="--force-confnew" \
        python3-rosdep python3-rosinstall-generator python3-wstool python-wstool \
        python3-rosinstall build-essential \
        python3-catkin-tools git python-pip python3-pip
    pip3 install pycryptodome
#
    echo '-------- rosdep init   -----'
    echo "$(whoami) ---"
#    [ ! -d /etc/ros/rosdep/sources.list.d/ ] && mkdir -p /etc/ros/rosdep/sources.list.d/ 
#    wget -O /etc/ros/rosdep/sources.list.d/20-default.list https://raw.githubusercontent.com/ros/rosdistro/master/rosdep/sources.list.d/20-default.list || echo 'wget failt to get list -------------------------'
    [ -f /etc/ros/rosdep/sources.list.d/20-default.list ] && rm /etc/ros/rosdep/sources.list.d/20-default.list
    rosdep init || echo 'rosdep init failed ----' #&& exit 1
#    rosdep fix-permissions
#    #rosdep init || echo 'rosdep init failed'
#    echo '-------- rosdep update -----'
    rosdep update || echo 'rosdep update failed' #&& exit 1
}

install_ros_base(){
    # THIS FUNCTION EXPECTS TO HAVE ur_driver_deps at root directory

    echo '-------- Generating ROS base image -----'
    mkdir -p /ros_ws/src
    cd /ros_ws
    # 1) generated data to install ros
    [ -f ros.rosinstall ] && rm ros.rosinstall
    [ -f src/.rosinstall ] && rm src/.rosinstall
    rosinstall_generator controller_manager_msgs roscpp std_msgs controller_interface hardware_interface joint_trajectory_controller pluginlib realtime_tools actionlib_msgs message_generation actionlib control_msgs controller_manager geometry_msgs industrial_robot_status_interface sensor_msgs std_srvs tf tf2_geometry_msgs tf2_msgs trajectory_msgs robot_state_publisher joint_state_publisher map_msgs position_controllers tf_conversions joint_state_controller velocity_controllers force_torque_sensor_controller --rosdistro noetic --deps --wet-only --tar > ros.rosinstall
    # 2) use wstool to download the sources
    wstool init -j8 src ros.rosinstall


    # 3 ) use rosdep to install system dependencies
    #    -r: Continue installing despite errors.
    #    -q: Quiet. Suppress output except for errors.
    #   --ignore-src:  Affects the 'check', 'install', and 'keys'
    #                 verbs. If specified then rosdep will ignore
    #                 keys that are found to be catkin or ament
    #                 packages anywhere in the ROS_PACKAGE_PATH,
    #                 AMENT_PREFIX_PATH or in any of the
    #                 directories given by the --from-paths
    #                 option.
    rosdep install -r -q  --from-paths src --ignore-src --rosdistro noetic -y

    # 4) compile with cmake
    #./src/catkin/bin/catkin_make_isolated --install \
    catkin config \
     --install \
        -DCMAKE_BUILD_TYPE=Release \
        --install-space /opt/ros/noetic -j2 \
        -DPYTHON_EXECUTABLE=/usr/bin/python3 \
        -DCATKIN_SKIP_TESTING=ON

    catkin config
    catkin env
    catkin clean -y
    catkin build

    # 5) append enviroment variables to bashrc
}
#
install_ur_driver(){

    mkdir -p /ros_ur_ws/src
    cd /ros_ur_ws
    source /opt/ros/noetic/setup.bash
    git clone https://github.com/UniversalRobots/Universal_Robots_ROS_Driver.git src/Universal_Robots_ROS_Driver
    git clone -b calibration_devel_tiny https://github.com/rafaelrojasmiliani/universal_robot.git src/rrojas_universal_robot
    git clone -b boost https://github.com/UniversalRobots/Universal_Robots_Client_Library.git src/Universal_Robots_Client_Library
    rosdep update
    rosdep install -r -q --from-paths src --ignore-src -y
    catkin_make_isolated --install-space /opt/ros/noetic -j2
}

install_cmake(){

    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o \
        Dpkg::Options::="--force-confnew" \
                        gnupg python3 python3-dev python3-pip build-essential \
                        libyaml-cpp-dev lsb-release isc-dhcp-server \
                        wget ca-certificates ntpdate curl libssl-dev gfortran

    CMAKEVERSION="3.21.0"

    [ -f /cmake-$CMAKEVERSION.tar.gz ] && rm /cmake-$CMAKEVERSION.tar.gz
    [ -d /cmake-$CMAKEVERSION ] && rm -rf /cmake-$CMAKEVERSION
    cd / && \
        curl -OL https://github.com/Kitware/CMake/releases/download/v$CMAKEVERSION/cmake-$CMAKEVERSION.tar.gz && \
        tar -xzf cmake-$CMAKEVERSION.tar.gz && \
        cd /cmake-$CMAKEVERSION && \
         ./bootstrap --prefix=/usr -- -D_FILE_OFFSET_BITS=64 && \
         make -j 30 && \
         /cmake-$CMAKEVERSION/bin/cpack -G DEB  && \
         dpkg -i /cmake-$CMAKEVERSION/cmake*.deb

}
main(){
    export SSL_CERT_FILE=/usr/lib/ssl/certs/ca-certificates.crt
    install_cmake
    install_sistem_deps
    install_ros_base
    install_ur_driver
}

main
