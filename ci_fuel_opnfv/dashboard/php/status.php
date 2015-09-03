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
    <title> OPNFV CI Status </title>

    <meta http-equiv="refresh" content="1" />
  </head>
  <body>
    <p>
       <?php 
         function show_status($ci_status, $icon, $font_color) {
	    echo '<img style="vertical-align:middle" src="',$icon,'" height="100" width="100">';
            echo '<font size="4" color="',$font_color,'"><b>    ',$ci_status['status'],'</b> since: ',$ci_status['since'],'</font>';
            if ($ci_status["status"] != "IDLE") {
               echo "</br></br>";
               echo "<table style=\"with:100%\">";
               echo "<tr>";
               echo '<td><b><font size="2">Build-ID:</font></b></td>';
               echo "<td></td>";
               echo '<td><b><font size="2">Started:</font></b></td>';
               echo "<td></td>";
               echo '<td><b><font size="2">Branch:</font></b></td>';
               echo "<td></td>";
               echo '<td><b><font size="2">Commit-id:</font></b></td>';
               echo "<td></td>";
               echo '<td><b><font size="2">Log file:</font></b></td>';
               echo "<td></td>";
               echo '<td><b><font size="2">ci_pipeline args:</font></b></td>';
               echo "</tr>";

               echo "<tr>";
               echo '<td><font size="2">',$ci_status['build_id'],'</td>';
               echo "<td></td>";
               echo '<td><font size="2">',$ci_status['build_id'],'</font></td>';
               echo "<td></td>";
               echo '<td><font size="2">',$ci_status['branch'],'</font></td>';
               echo "<td></td>";
               echo '<td><font size="2">',$ci_status['commit_id'],'</font></td>';
               echo "<td></td>";
               echo '<td><font size="2"> <a href="file://',$ci_status['log'],'">Link</a></font></td>';
               echo "<td></td>"; 
               echo "<td></td>"; 
               echo "</tr>";
               echo "</table>";
            } 
         }

         $config_file="config.yaml";
         $config=yaml_parse_file($config_file);
         $repo_path=$config["ci_repo_path"];
         $status_file="/var/run/fuel/ci-status";
        
         $ci_status=get_metadata($status_file, $repo_path);

         switch ($ci_status["status"]) {
            case "IDLE":
               show_status($ci_status,"images/idle.png","grey");
            break;

            case "CLONING":
               show_status($ci_status,"images/clone.png","blue");
            break;

            case "BUILDING":
               show_status($ci_status,"images/build.png","green");
            break;
       
            case "DEPLOYING":
               show_status($ci_status,"images/deploy.png","orange");
            break;

            case "FUNCTEST_PREP":
               show_status($ci_status,"images/test.png","red");
            break;

            case "FUNCTEST_TEMPEST":
               show_status($ci_status,"images/test.png","red");
            break;

            case "FUNCTEST_RALLY":
               show_status($ci_status,"images/test.png","red");
            break;

            case "FUNCTEST_ODL":
               show_status($ci_status,"images/test.png","red");
            break;

            case "FUNCTEST_VPING":
               show_status($ci_status,"images/test.png","red");
            break;

            case "CLEANING":
               show_status($ci_status,"images/clean.png","blue");
            break;
          }
          echo "</pre>";
    ?>
    </p>
  </body>
</html>
