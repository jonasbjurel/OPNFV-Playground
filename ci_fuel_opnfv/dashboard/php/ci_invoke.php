<!--#########################################################################-->
<!--# Copyright (c) 2015 Jonas Bjurel and others.                            -->
<!--# jonasbjurel@hotmail.com                                                -->
<!--# All rights reserved. This program and the accompanying materials       -->
<!--# are made available under the terms of the Apache License, Version 2.0  -->
<!--# which accompanies this distribution, and is available at               -->
<!--# http://www.apache.org/licenses/LICENSE-2.0                             -->
<!--#########################################################################-->
<html>
  <head>
<!--    <meta http-equiv="refresh" content="10" /> -->
  </head>
  <body>
    <p>
      <?php
         $config_file="../config.yaml";
         $config=yaml_parse_file($config_file);
         $repo_path=$config["ci_repo_path"];

         $release=$_GET["release"];
         $build_staging=$_GET["build_staging"];
         $deploy_staging=$_GET["deploy_staging"];
         $test_staging=$_GET["test_staging"];
         $build_params=$_GET["build_params"];
         $deploy_params=$_GET["deploy_params"];
         $iso_file=$_GET["iso_file"];

         if ((isset($build_staging))||(isset($deploy_staging))||(isset($test_staging))) {

            $command="./ci_pipeline.sh ";
            $command.="-b $release ";

            if (!(isset($build_staging)))
               $command.="-B ";
            if (!(isset($deploy_staging)))
               $command.="-D ";
            if (!(isset($test_staging)))
               $command.="-T ";

            if ((isset($build_params)) && ($build_params=="no_cache"))
               $command.="-I ";

            if ((isset($deploy_params)) && ($deploy_params=="ha"))
               $command.="-a ";

            if (isset($iso_file) && !(empty($iso_file)))
               $command.="-i $iso_file ";

            echo "running $command";
            exec("$repo_path/ci_fuel_opnfv/$command >/dev/null 2>/dev/null &");
            //sleep(10);
            //header("Location: {$_SERVER['HTTP_REFERER']}");
        }
        else
           echo "Nothing todo";
           //sleep(10);
           //header("Location: {$_SERVER['HTTP_REFERER']}");
      ?>
    </p>
  </body>
</html>
