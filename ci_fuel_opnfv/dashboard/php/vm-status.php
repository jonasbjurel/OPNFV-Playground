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
    <title> OPNFV VM Status </title>
<!--    <meta http-equiv="refresh" content="10" /> -->
    <meta http-equiv="refresh" content="10" />
  </head>
  <body>
    <p>
      <?php
         $config_file="config.yaml";
         $config=yaml_parse_file($config_file);
         $repo_path=$config["ci_repo_path"];
         $status_file="/var/run/fuel/ci-status";
         $virsh_res=shell_exec('virsh list --all | egrep -i "fuel|controller|compute"');
         $vm = explode("\n", $virsh_res);
         echo "<pre>";
         echo "<table style=\"with:100%\">";
         $cnt=0;
         echo '<td><b>VM State</b></td>';
         while (isset($vm[$cnt+1])) {
            list($dummy, $id[$cnt], $vm_name[$cnt], $status[$cnt]) = preg_split('/\s+/', $vm[$cnt]);
            if ($status[$cnt]=="running")
               echo '<td align="center"><b><img style="vertical-align:middle" src="images/play.png" height="50" width="50"</b></td>';
            else
               echo '<td align="center"><b><img style="vertical-align:middle" src="images/idle.png" height="50" width="50"</b></td>';
            echo "<td></td>";
            $cnt++;
         }
         echo "<tr>";
         echo '<td><b><font size="2">VM Name</font></b></td>';
         $cnt=0;
         while (isset($vm[$cnt+1])) {
            echo '<td align="center"><font size="2"><b>',$vm_name[$cnt],'</font></b></td>';
            echo "<td></td>";
            $cnt++;
         }
         echo "<tr>";
         echo '<td><b><font size="2">CPU Stats</font></b></td>';
         echo "<tr>";
         echo '<td><b><font size="2">MEM Stats</font></b></td>';
         echo "<tr>";
         echo '<td><b><font size="2">IO Stats</font></b></td>';
         echo "</table>";
         echo "</pre>";
    ?>
    </p>
  </body>
</html>
