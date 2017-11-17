<?php

$applicationDirectory = realpath(dirname(__FILE__) . DIRECTORY_SEPARATOR . '..' . DIRECTORY_SEPARATOR);
$projectRoot = $applicationDirectory . DIRECTORY_SEPARATOR . '..' . DIRECTORY_SEPARATOR . '..' . DIRECTORY_SEPARATOR . '..' . DIRECTORY_SEPARATOR . '..';

// Selection of migrations to apply in clean-db vs user-generated DATA scenario
$modulePaths = array();
if (DATA == "clean-db") {
    $modulePaths['clean-db-only'] = 'dna.db.migrations.clean-db-only';
} else {
    $modulePaths['user-generated-only'] = 'dna.db.migrations.' . DATA . '-only';
}

$consoleConfig = array(
    'aliases' => array(
        'root' => $projectRoot,
        'app' => $applicationDirectory,
        'vendor' => $projectRoot . DIRECTORY_SEPARATOR . 'vendor',
        'dna' => $projectRoot . DIRECTORY_SEPARATOR . 'dna',
    ),
    'basePath' => $applicationDirectory,
    'name' => 'Yii DNA Pre-Release Testing Console Application',
    'import' => array(
        'dna.vendor.neam.yii-relational-graph-db.traits.RelatedNodesDatabaseRoutineGeneratorTrait',
    ),
    'commandMap' => array(
        // fixtureHelper
        'fixture' => array(
            'class' => 'vendor.sumwai.yii-fixture-helper.FixtureHelperCommand',
            'defaultFixturePathAlias' => 'dna.fixtures',
            'defaultModelPathAlias' => 'dna.models',
        ),
        // db commands
        'databaseschema' => array(
            'class' => 'app.commands.DatabaseSchemaCommand',
        ),
        'mysqldump' => array(
            'class' => 'vendor.motin.yii-consoletools.commands.MysqldumpCommand',
            'basePath' => $projectRoot,
            'dumpPath' => '/db',
        ),
        // dna-specific commands
        'databaseviewgenerator' => array(
            'class' => 'dna.commands.DatabaseViewGeneratorCommand',
        ),
        'databaseroutinegenerator' => array(
            'class' => 'dna.commands.DatabaseRoutineGeneratorCommand',
        ),
        'worker' => array(
            'class' => 'dna.commands.WorkerCommand',
        ),
    ),
    'components' => array(
        'fixture-helper' => array(
            'class' => 'vendor.sumwai.yii-fixture-helper.FixtureHelperDbFixtureManager',
        ),
    ),
);

$config = array();

// Import the DNA classes and configuration into $config
require($projectRoot . '/dna/config/DnaConfig.php');
DnaConfig::applyConfig($config);

// create base console config from web configuration
$consoleRelevantDnaConfig = array(
    'name' => $config['name'],
    'language' => $config['language'],
    'aliases' => $config['aliases'],
    'import' => $config['import'],
    'components' => $config['components'],
    'modules' => $config['modules'],
    'params' => $config['params'],
);

// apply console config
$consoleConfig = CMap::mergeArray($consoleRelevantDnaConfig, $consoleConfig);

return $consoleConfig;
